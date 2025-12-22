-- ParryService.lua
-- Server-authoritative parry timing module for Sekiro-style mechanics.

local ParryService = {}

-- Safe require for shared CombatConfig (if available)
local successConfig, SharedConfig = (function()
    local parent = script.Parent
    if not parent then return false, nil end
    local shared = parent:FindFirstChild("shared")
    if not shared then return false, nil end
    local cfg = shared:FindFirstChild("CombatConfig")
    if not cfg or not cfg:IsA("ModuleScript") then return false, nil end
    local ok, mod = pcall(require, cfg)
    if not ok or type(mod) ~= "table" then return false, nil end
    return true, mod
end)()

-- Safe require for server CombatService to apply guard damage / stagger if available
local successCombat, CombatService = (function()
    local parent = script.Parent
    if not parent then return false, nil end
    local mod = parent:FindFirstChild("CombatService")
    if not mod or not mod:IsA("ModuleScript") then return false, nil end
    local ok, m = pcall(require, mod)
    if not ok or type(m) ~= "table" then return false, nil end
    return true, m
end)()

-- Local defaults
local Config = {
    ParryWindow = 0.15, -- perfect parry window (seconds)
    ParryCooldown = 0.8, -- seconds to prevent spam
    ParryStagger = 0.3,  -- stagger applied to attacker on success
    ParrySuccessGuardDamage = 30,
    FailedParryGuardPenalty = 20, -- extra guard damage taken on failed parry
}

if successConfig and type(SharedConfig) == "table" then
    for k, v in pairs(SharedConfig) do
        Config[k] = Config[k] or v
    end
    -- prefer explicit parry values from SharedConfig if present
    if SharedConfig.ParryTimingWindow then Config.ParryWindow = SharedConfig.ParryTimingWindow end
    if SharedConfig.Parry and SharedConfig.Parry.SuccessGuardDamage then
        Config.ParrySuccessGuardDamage = SharedConfig.Parry.SuccessGuardDamage
    end
    if SharedConfig.StaggerDurations and SharedConfig.StaggerDurations.ParryStagger then
        Config.ParryStagger = SharedConfig.StaggerDurations.ParryStagger
    end
end

-- Helper: validate minimal entity contract
local function isValidEntity(e)
    return type(e) == "table" and e.Health and e.Guard
end

-- Helper: quality multiplier (if Equipment.Quality exists)
local function qualityMultiplier(e)
    local q = (e and e.Equipment and e.Equipment.Quality) or 0
    return 1 + q * 0.002
end

-- IsPerfectParry(player, attackTime)
-- attackTime: predicted hit time (number)
-- Returns boolean
function ParryService.IsPerfectParry(player, attackTime)
    if not isValidEntity(player) or type(attackTime) ~= "number" then
        return false
    end
    local now = os.clock()
    local delta = math.abs(now - attackTime)
    local window = Config.ParryWindow
    -- slight quality bonus if player has equipment quality
    local effectiveWindow = window + (player.Equipment and (player.Equipment.Quality or 0) * 0.0005) or window
    return delta <= effectiveWindow
end

-- AttemptParry(player, incomingAttackTime)
-- Returns table { success = bool, perfect = bool, reason = string?, details = table? }
function ParryService.AttemptParry(player, incomingAttackTime)
    if not isValidEntity(player) then
        return { success = false, reason = "invalid_player" }
    end

    local now = os.clock()

    -- cooldown check
    if player._parryCooldownUntil and now < player._parryCooldownUntil then
        return { success = false, reason = "cooldown" }
    end

    -- incoming attack validation: prefer server-tracked incoming attack if available
    local incoming = player._incomingAttack
    if not incoming or type(incoming.attackTime) ~= "number" then
        -- no incoming attack recorded on server
        return { success = false, reason = "no_incoming" }
    end

    -- ensure provided attack time matches server's record (small tolerance)
    if incomingAttackTime and math.abs(incomingAttackTime - incoming.attackTime) > 0.05 then
        -- mismatch - client may be lying or out-of-sync
        return { success = false, reason = "attack_time_mismatch" }
    end

    local delta = math.abs(now - incoming.attackTime)
    local window = Config.ParryWindow
    -- equipment quality slightly increases window
    if player.Equipment and player.Equipment.Quality then
        window = window + player.Equipment.Quality * 0.0005
    end

    local isPerfect = delta <= window

    -- set cooldown to prevent spam
    player._parryCooldownUntil = now + Config.ParryCooldown

    if isPerfect then
        -- Successful parry: cancel incoming attack, stagger attacker, apply guard damage to attacker,
        -- and flag player's next M1 to bypass guard.
        local attacker = incoming.attacker
        -- cancel incoming attack
        player._incomingAttack = nil
        -- flag next M1 to bypass guard
        player._nextM1BypassGuard = true

        -- apply stagger and guard damage to attacker if CombatService available
        if successCombat and isValidEntity(attacker) then
            -- stagger
            attacker._staggerUntil = math.max((attacker._staggerUntil or 0), now + Config.ParryStagger)
            -- guard damage with quality scaling
            local qmult = qualityMultiplier(player)
            local guardDmg = Config.ParrySuccessGuardDamage * qmult
            CombatService.ApplyGuardDamage(attacker, guardDmg)
        else
            -- if CombatService not present, still set attacker flags if table
            if isValidEntity(attacker) then
                attacker._staggerUntil = math.max((attacker._staggerUntil or 0), now + Config.ParryStagger)
                -- best-effort reduce guard
                attacker.Guard = math.max(0, (attacker.Guard or 0) - Config.ParrySuccessGuardDamage)
            end
        end

        return { success = true, perfect = true, stagger = Config.ParryStagger }
    else
        -- Failed parry: player takes increased guard damage
        local penalty = Config.FailedParryGuardPenalty
        -- scale by attacker's quality if present
        local attacker = incoming.attacker
        if isValidEntity(attacker) and attacker.Equipment and attacker.Equipment.Quality then
            penalty = penalty * (1 + attacker.Equipment.Quality * 0.001)
        end
        -- apply guard damage to player
        if successCombat then
            CombatService.ApplyGuardDamage(player, penalty)
        else
            player.Guard = math.max(0, (player.Guard or 0) - penalty)
        end

        -- clear incoming attack so the attack proceeds immediately (no cancellation)
        player._incomingAttack = nil
        return { success = false, perfect = false, reason = "timing", appliedGuardDamage = penalty }
    end
end

return ParryService
