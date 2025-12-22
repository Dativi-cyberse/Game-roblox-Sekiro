-- CombatRemoteHandler.lua
-- Server-side RemoteEvent bridge: safely receives client attack/parry requests,
-- validates payloads, performs server-side hit detection (raycast), and applies
-- damage or guard effects using PlayerState / Humanoid. Do NOT trust client data.

-- Combo logic (server):
-- - Server validates the `combo` index sent by the client against the weapon's
--   config stored in ReplicatedStorage (fields: `ComboCount` or `Combo1`..`ComboN`).
-- - The server clamps the client-provided combo index to [1, maxCombo] and only then
--   selects damage/guard values (supports per-step `Damage1`, `Damage2`, ... fields).
-- - Server performs authoritative hit detection (raycast) and applies damage via
--   PlayerState or `Humanoid:TakeDamage`. Clients only request actions; they never
--   declare hits or apply damage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Wait for the RemoteEvent that clients will FireServer to request combat actions.
local REMOTE_NAME = "CombatEvent"
local CombatEvent = ReplicatedStorage:WaitForChild(REMOTE_NAME)

-- Local requires
local HealthManager
local CombatService
local PlayerStateModule
do
    local servFolder = script.Parent
    local healthMod = servFolder:FindFirstChild("HealthManager")
    if healthMod then
        HealthManager = require(healthMod)
    end
    local combatMod = servFolder:FindFirstChild("CombatService")
    if combatMod then
        CombatService = require(combatMod)
    end
    local sharedRoot = script.Parent.Parent and script.Parent.Parent:FindFirstChild("shared")
    if sharedRoot then
        local ps = sharedRoot:FindFirstChild("PlayerState")
        if ps then
            PlayerStateModule = require(ps)
        end
    end
end

-- Ensure required modules exist; fail early with warnings if not
if not PlayerStateModule then
    warn("CombatRemoteHandler: shared.PlayerState not found; player state operations will error")
end
if not HealthManager then
    warn("CombatRemoteHandler: HealthManager not found; NPC health helpers not available")
end
if not CombatService then
    -- CombatService is optional for tuning fallback; not fatal
    warn("CombatRemoteHandler: CombatService not found; using basic fallbacks")
end

-- Map player -> PlayerState instance
local playerStates = {}

local function ensurePlayerState(player)
    if not player then return nil end
    if playerStates[player] then return playerStates[player] end
    local st = PlayerStateModule.new()
    playerStates[player] = st
    return st
end

Players.PlayerAdded:Connect(function(player)
    ensurePlayerState(player)
end)
Players.PlayerRemoving:Connect(function(player)
    playerStates[player] = nil
end)

-- Anti-exploit maps: per-player cooldowns and recent attack timestamps
local playerCooldowns = setmetatable({}, { __mode = "k" }) -- weak keys

local MIN_ATTACK_INTERVAL = 0.05 -- server-side minimum interval between attacks
local MAX_CLIENT_TIME_DRIFT = 2.0 -- seconds (reject wildly out-of-sync attackTime)

local function hasEquippedWeapon(player, weaponName)
    if not player then return false end
    local char = player.Character
    if not char then return false end
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            -- prefer Tool.Name match; if tool has a StringValue 'WeaponName' prefer that
            if child.Name == weaponName then
                return true
            end
            local wn = child:FindFirstChild("WeaponName")
            if wn and wn:IsA("StringValue") and wn.Value == weaponName then
                return true
            end
        end
    end
    return false
end

-- Exploit telemetry: counts rejected attempts per-player per-reason (weak keys)
local exploitCounts = setmetatable({}, { __mode = "k" })
local function recordExploit(player, reason)
    if not player then return end
    exploitCounts[player] = exploitCounts[player] or {}
    exploitCounts[player][reason] = (exploitCounts[player][reason] or 0) + 1
end

-- Read weapon configuration from ReplicatedStorage (Folder + ValueObjects or Attributes)
local function readWeaponConfig(weaponName)
    local root = ReplicatedStorage:FindFirstChild("WeaponConfig") or ReplicatedStorage:FindFirstChild("Weapons") or ReplicatedStorage:FindFirstChild("WeaponConfigs")
    if not root then
        return nil
    end
    local folder = root:FindFirstChild(weaponName)
    if not folder or not folder:IsA("Folder") then
        return nil
    end
    local cfg = {}
    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("NumberValue") then
            cfg[child.Name] = child.Value
        elseif child:IsA("StringValue") then
            cfg[child.Name] = child.Value
        elseif child:IsA("BoolValue") then
            cfg[child.Name] = child.Value
        end
    end
    for k, v in pairs(folder:GetAttributes()) do
        cfg[k] = v
    end
    return cfg
end

-- Utility: safe number
local function safeNumber(v, def)
    if type(v) ~= "number" then return def end
    return v
end

local function clamp(n, a, b)
    if n < a then return a end
    if n > b then return b end
    return n
end

-- Server-side handler for attack requests
local function handleAttackRequest(player, payload)
    -- minimal validation of payload shape
    if type(payload) ~= "table" then return end
    local weapon = tostring(payload.weapon or "Sword")
    local holdTime = tonumber(payload.holdTime) or 0

    -- get player's character and root part
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end

    -- read weapon config from ReplicatedStorage; fallback to CombatService config
    local cfg = readWeaponConfig(weapon)
    local range = safeNumber(cfg and cfg.Range or cfg and cfg.range or (CombatService and CombatService.Config and CombatService.Config.Weapons and (CombatService.Config.Weapons[weapon] and CombatService.Config.Weapons[weapon].range) ), 5)
    local baseDamage = safeNumber(cfg and cfg.Damage or cfg and cfg.damage or 10, 10)
    local baseGuardDamage = safeNumber(cfg and cfg.GuardDamage or cfg and cfg.guardDamage or 5, 5)

    -- Determine combo support and validate client-provided combo index.
    -- Server MUST validate combo index: clients may send arbitrary numbers.
    local maxCombo = 1
    if cfg and cfg.ComboCount and type(cfg.ComboCount) == "number" then
        maxCombo = math.max(1, math.floor(cfg.ComboCount))
    else
        -- infer by checking for Combo1..Combo8 fields in config
        for i = 1, 8 do
            if cfg and cfg["Combo" .. tostring(i)] then
                maxCombo = i
            end
        end
    end

    local clientCombo = tonumber(payload and payload.combo) or 1
    local comboIndex = clamp(clientCombo, 1, maxCombo)

    -- Allow per-step damage config: Damage1, Damage2, etc; fallback to baseDamage
    local damage = baseDamage
    local guardDamage = baseGuardDamage
    if cfg and cfg["Damage" .. tostring(comboIndex)] then
        damage = safeNumber(cfg["Damage" .. tostring(comboIndex)], baseDamage)
    end
    if cfg and cfg["GuardDamage" .. tostring(comboIndex)] then
        guardDamage = safeNumber(cfg["GuardDamage" .. tostring(comboIndex)], baseGuardDamage)
    end

    -- Server-side sanity checks / anti-exploit
    local serverNow = os.clock()
    local attackTime = tonumber(payload and payload.attackTime) or serverNow
    if math.abs(serverNow - attackTime) > MAX_CLIENT_TIME_DRIFT then
        -- client time too far out; ignore request
        warn("CombatRemoteHandler: rejected attack due to time drift", player.Name)
        recordExploit(player, "time_drift")
        return
    end

    -- Verify player actually has the weapon equipped (prevents clients faking weapon names)
    if not hasEquippedWeapon(player, weapon) then
        warn("CombatRemoteHandler: player does not have weapon equipped", player.Name, weapon)
        recordExploit(player, "no_weapon")
        return
    end

    -- Per-player, per-weapon cooldown enforcement
    playerCooldowns[player] = playerCooldowns[player] or {}
    local lastForWeapon = playerCooldowns[player][weapon]
    local cooldown = safeNumber(cfg and cfg.Cooldown or cfg and cfg.CooldownTime or 0.2, 0.2)
    if lastForWeapon and (serverNow - lastForWeapon) < math.max(cooldown, MIN_ATTACK_INTERVAL) then
        -- too fast
        recordExploit(player, "cooldown")
        return
    end
    -- Record this attempt now (prevents re-entrancy/exploit)
    playerCooldowns[player][weapon] = serverNow

    -- server-side box overlap (preferred over :Touched):
    -- Build an oriented hitbox in front of the attacker and get overlapping parts.
    -- This avoids relying on Touched events and gives consistent per-swing detection.
    local OverlapParams = OverlapParams.new()
    OverlapParams.FilterDescendantsInstances = { char }
    OverlapParams.FilterType = Enum.RaycastFilterType.Blacklist

    -- Hitbox size: Z depth = range, X = width, Y = height. These can be configured per-weapon.
    local hitboxWidth = safeNumber(cfg and cfg.HitboxWidth or cfg and cfg.HitboxSizeX, 3)
    local hitboxHeight = safeNumber(cfg and cfg.HitboxHeight or cfg and cfg.HitboxSizeY, 4)
    local hitboxDepth = safeNumber(range, 5)
    local size = Vector3.new(hitboxWidth, hitboxHeight, hitboxDepth)

    -- Center the box in front of the HumanoidRootPart at half the range
    local origin = hrp.Position
    local centerPos = origin + (hrp.CFrame.LookVector * (hitboxDepth * 0.5))
    local boxCFrame = CFrame.new(centerPos, centerPos + hrp.CFrame.LookVector)

    -- Get overlapping parts inside the oriented box
    local parts = workspace:GetPartBoundsInBox(boxCFrame, size, OverlapParams)
    if not parts or #parts == 0 then
        return -- no hit
    end

    -- Collect unique humanoids hit (prevent multiple hits on same humanoid per swing)
    local hitHumanoids = {}
    local function addHumanoidFromPart(part)
        if not part or not part:IsDescendantOf(workspace) then return end
        local model = part:FindFirstAncestorOfClass("Model")
        if not model then return end
        local hum = model:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        if hum.Parent == char then return end -- avoid self-hit
        if hitHumanoids[hum] then return end
        hitHumanoids[hum] = true
    end

    for _, part in ipairs(parts) do
        addHumanoidFromPart(part)
    end

    -- No humanoid found
    local anyHum = next(hitHumanoids)
    if not anyHum then return end

    -- Process each unique humanoid target
    for hum, _ in pairs(hitHumanoids) do
        local targetHum = hum

        -- distance check: ensure target is within configured range (server authoritative)
        local targetRoot = targetHum.Parent and (targetHum.Parent:FindFirstChild("HumanoidRootPart") or targetHum.Parent:FindFirstChild("Torso"))
        local withinRange = true
        if targetRoot then
            local dist = (targetRoot.Position - hrp.Position).Magnitude
            if dist > (range + 1) then
                withinRange = false
            end
        end

        if not withinRange then
            -- skip targets outside server-authoritative range
        else
            local targetPlayer = Players:GetPlayerFromCharacter(targetHum.Parent)
            if targetPlayer and playerStates[targetPlayer] then
                if CombatService and CombatService.ProcessAttack then
                    -- Build attacker/target entity tables expected by CombatService.ProcessAttack
                    local attackerState = playerStates[player]
                    local attackerEntity = {
                        Health = attackerState and attackerState.Health or (humanoid and humanoid.Health) or 0,
                        MaxHealth = attackerState and attackerState.MaxHP or (humanoid and humanoid.MaxHealth) or 0,
                        Shield = attackerState and attackerState.Guard or 0,
                        MaxShield = attackerState and attackerState.MaxGuard or 0,
                        IsBoss = attackerState and attackerState.IsBoss or false,
                        Stats = attackerState and attackerState.Stats or {},
                        Equipment = attackerState and attackerState.Equipment or {},
                    }

                    local targetState = playerStates[targetPlayer]
                    local targetEntity = {
                        Health = targetState and targetState.Health or (targetHum and targetHum.Health) or 0,
                        MaxHealth = targetState and targetState.MaxHP or (targetHum and targetHum.MaxHealth) or 0,
                        Shield = targetState and targetState.Guard or 0,
                        MaxShield = targetState and targetState.MaxGuard or 0,
                        IsBoss = targetState and targetState.IsBoss or false,
                        Stats = targetState and targetState.Stats or {},
                        Equipment = targetState and targetState.Equipment or {},
                    }

                    local weaponTable = {
                        BaseDamage = damage,
                        ShieldDamage = guardDamage,
                        Quality = cfg and cfg.Quality or 1.0,
                    }

                    -- Call authoritative combat logic
                    local ok, res = pcall(function()
                        return CombatService.ProcessAttack(attackerEntity, targetEntity, weaponTable)
                    end)

                    if not ok then
                        warn("CombatRemoteHandler: CombatService.ProcessAttack failed:", res)
                        if cfg and cfg.Debug then
                            print("[CombatDebug] ProcessAttack error for", player.Name, "->", targetPlayer.Name, res)
                        end
                    else
                        if cfg and cfg.Debug then
                            print("[CombatDebug] Hit", player.Name, "->", targetPlayer.Name, "combo", comboIndex, "damage", damage)
                        end
                        -- Write back mutated values to authoritative storage (PlayerState or Humanoid)
                        if attackerState then
                            attackerState.Health = math.max(0, math.min(attackerEntity.Health or attackerState.Health, attackerState.MaxHP))
                            attackerState.Guard = math.max(0, math.min(attackerEntity.Shield or attackerState.Guard, attackerState.MaxGuard))
                        elseif humanoid then
                            humanoid.Health = math.max(0, math.min(attackerEntity.Health or humanoid.Health, humanoid.MaxHealth))
                        end

                        if targetState then
                            targetState.Health = math.max(0, math.min(targetEntity.Health or targetState.Health, targetState.MaxHP))
                            targetState.Guard = math.max(0, math.min(targetEntity.Shield or targetState.Guard, targetState.MaxGuard))
                        else
                            -- apply to NPC humanoid
                            if targetHum and type(targetEntity.Health) == "number" then
                                targetHum.Health = math.max(0, math.min(targetEntity.Health, targetHum.MaxHealth))
                            end
                        end
                    end
                else
                    -- Fallback behavior if CombatService is missing: simple guard then damage
                    local targetState = playerStates[targetPlayer]
                    if targetState then
                        targetState:TakeGuardDamage(guardDamage)
                        if targetState.IsGuardBroken then
                            targetState:TakeDamage(damage)
                        end
                        if cfg and cfg.Debug then
                            print("[CombatDebug] Fallback hit", player.Name, "->", targetPlayer.Name, "combo", comboIndex, "damage", damage)
                        end
                    end
                end
            else
                -- Non-player target (NPC): apply direct humanoid damage once
                if targetHum and targetHum.Health > 0 then
                    targetHum:TakeDamage(damage)
                    if cfg and cfg.Debug then
                        print("[CombatDebug] NPC hit", player.Name, "->", tostring(targetHum.Parent and targetHum.Parent.Name), "combo", comboIndex, "damage", damage)
                    end
                end
            end
        end
    end
end

local function handleParryRequest(player, payload)
    if type(payload) ~= "table" then return end
    local time = tonumber(payload.time) or os.clock()
    local st = ensurePlayerState(player)
    -- mark parry attempt on server-side state (server decides success when an attack lands)
    st.IsParrying = true
    st._parryStart = time
    -- clear parry window shortly after (server authoritative)
    task.delay(1.0, function()
        st.IsParrying = false
    end)
end

CombatEvent.OnServerEvent:Connect(function(player, payload)
    if not player or type(payload) ~= "table" then return end
    local action = tostring(payload.action or "")
    if action == "attack" then
        handleAttackRequest(player, payload)
    elseif action == "parry" then
        handleParryRequest(player, payload)
    else
        -- unrecognized action; ignore
        return
    end
end)

-- Add comments: This server script performs minimal but essential validation:
--  - Uses server-side raycast to determine hit targets (clients should not declare hits)
--  - Reads weapon tuning from ReplicatedStorage Folders/Values (not ModuleScripts)
--  - Applies damage through PlayerState for players, and Humanoid:TakeDamage for NPCs as fallback
--  - Server remains authoritative; client is only allowed to request actions and play local animations

return nil
