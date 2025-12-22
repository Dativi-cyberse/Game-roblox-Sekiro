-- CombatHandler.lua
-- Server-side module handling clash and parry interactions and hit validation.

local CombatHandler = {}

local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")
function CombatHandler:ApplyDamage(player)
	local char = player.Character
	if not char then return end

	-- hitbox + damage logic
end

-- Config
local CLASH_WINDOW = 0.1
local PARRY_STUN = 0.5
local PARRY_GUARD_BONUS = 30 -- extra guard damage to attacker on perfect parry

-- Minimal entity validator
local function isValidEntity(e)
    return type(e) == "table" and e.Health and e.Guard
end

-- Raycast helper (server-side validation)
local function raycastHit(attackerRoot, range)
    if not attackerRoot or not attackerRoot.Position then return nil end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = { attackerRoot }
    params.FilterType = Enum.RaycastFilterType.Blacklist
    local dir = attackerRoot.CFrame.LookVector * range
    local result = workspace:Raycast(attackerRoot.Position, dir, params)
    return result
end

-- Detect clash by comparing last attack timestamps on each entity
function CombatHandler.DetectClash(a, b)
    if not (isValidEntity(a) and isValidEntity(b)) then return false end
    if not a._lastAttackTime or not b._lastAttackTime then return false end
    return math.abs(a._lastAttackTime - b._lastAttackTime) <= CLASH_WINDOW
end

-- Handle a clash: cancel both attacks and apply knockback/stagger flags
function CombatHandler.ResolveClash(a, b)
    -- clear incoming attacks
    a._incomingAttack = nil
    b._incomingAttack = nil
    -- apply small guard loss (callers should use CombatService.ApplyGuardDamage for authoritative change)
    local guardLoss = 15
    if a.IsBoss then
        guardLoss = math.min(guardLoss, math.floor(a.GuardMax * 0.2 or 0))
    end
    if b.IsBoss then
        guardLoss = math.min(guardLoss, math.floor(b.GuardMax * 0.2 or 0))
    end
    a.Guard = math.max(0, (a.Guard or 0) - guardLoss)
    b.Guard = math.max(0, (b.Guard or 0) - guardLoss)
    -- stagger flags
    local now = os.clock()
    a._staggerUntil = now + 0.3
    b._staggerUntil = now + 0.3
    return { clash = true, guardLoss = guardLoss }
end

-- Handle a single attack validation & resolution
-- attacker, target: server-side entity tables
-- weaponInfo: { range = number, damage = number, guardDamage = number }
function CombatHandler.ResolveAttack(attacker, target, weaponInfo)
    if not (isValidEntity(attacker) and isValidEntity(target)) then
        return { ok = false, reason = "invalid_entity" }
    end

    -- simple hit test using raycast from attacker's root
    local hit = nil
    if attacker.RootPart then
        hit = raycastHit(attacker.RootPart, weaponInfo.range or 5)
    end

    -- use incoming attack times for clash detection
    if CombatHandler.DetectClash(attacker, target) then
        return CombatHandler.ResolveClash(attacker, target)
    end

    -- Parry check
    if target.IsParrying then
        -- attacker stunned
        attacker._staggerUntil = os.clock() + PARRY_STUN
        -- apply extra shield damage to attacker
        attacker.Guard = math.max(0, (attacker.Guard or 0) - (weaponInfo.guardDamage + PARRY_GUARD_BONUS))
        return { ok = true, parried = true }
    end

    -- If raycast didn't find, allow a small wait and retry (server-side leniency)
    if not hit then
        task.wait(0.02)
        if attacker.RootPart then
            hit = raycastHit(attacker.RootPart, weaponInfo.range or 5)
        end
    end

    if not hit then
        return { ok = false, reason = "miss" }
    end

    -- apply guard damage first
    local guardBefore = target.Guard or 0
    target.Guard = math.max(0, guardBefore - (weaponInfo.guardDamage or 0))
    local guardBroken = guardBefore > 0 and target.Guard <= 0

    if guardBroken then
        -- set broken flag and schedule recover
        target._brokenUntil = os.clock() + 1.0
    end

    -- if guard remains, no HP damage
    if target.Guard > 0 then
        return { ok = true, hit = true, guardRemaining = target.Guard }
    end

    -- guard is 0, apply HP damage
    target.Health = math.max(0, (target.Health or 0) - (weaponInfo.damage or 0))
    return { ok = true, hit = true, damageApplied = weaponInfo.damage }
end

return CombatHandler
