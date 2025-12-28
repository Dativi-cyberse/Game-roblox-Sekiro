-- CombatService.server.lua
-- Server-authoritative combat orchestration. Responsible for wiring shared combat
-- modules (DamageCalculator, GuardParry, ClashResolver, ShieldSystem, etc.)
-- into a single, deterministic API used by Remote handlers.

local Constants = require(script.Parent.Parent:FindFirstChild("shared").Modules.Core.Constants)
local DamageCalculator = require(script.Parent.Parent:FindFirstChild("shared").Modules.Combat.DamageCalculator)
local GuardParry = require(script.Parent.Parent:FindFirstChild("shared").Modules.Combat.GuardParry)
local ClashResolver = require(script.Parent.Parent:FindFirstChild("shared").Modules.Combat.ClashResolver)
local ShieldSystem = require(script.Parent.Parent:FindFirstChild("shared").Modules.Combat.ShieldSystem)
local Sprint = require(script.Parent.Parent:FindFirstChild("shared").Modules.Movement.Sprint)
local TargetValidator = require(script.Parent.Parent:FindFirstChild("shared").Modules.Targeting.TargetValidator)
local WeaponData = require(script.Parent.Parent:FindFirstChild("shared").Modules.Weapons.WeaponData)

local CombatService = {}

-- Public config that other server scripts may inspect for tuning/fallbacks.
CombatService.Config = {
    Weapons = {},
}

local function now()
    return os.clock()
end

local function isEntity(e)
    return type(e) == "table"
end

-- Apply guard (shield) damage to an entity table in a best-effort, defensive way.
-- Assumptions:
--  - entity may be a thin table (Health, Shield) or a richer PlayerState-like object.
--  - prefer `Shield` then `Guard` then `Posture` fields when applying guard damage.
function CombatService.ApplyGuardDamage(entity, amount)
    if not isEntity(entity) or type(amount) ~= "number" then return end
    local amt = math.max(0, amount)
    if entity.Shield ~= nil then
        entity.Shield = math.max(0, (entity.Shield or 0) - amt)
        if entity.Shield <= 0 then
            entity._isGuardBroken = true
            entity._staggerUntil = math.max(entity._staggerUntil or 0, now() + 0.6)
        end
        return
    end
    if entity.Guard ~= nil then
        entity.Guard = math.max(0, (entity.Guard or 0) - amt)
        if entity.Guard <= 0 then
            entity._isGuardBroken = true
            entity._staggerUntil = math.max(entity._staggerUntil or 0, now() + 0.6)
        end
        return
    end
    -- fallback: apply to Posture if present
    if entity.Posture ~= nil then
        entity.Posture = math.clamp((entity.Posture or Constants.POSTURE_MAX) - amt, 0, Constants.POSTURE_MAX)
        if entity.Posture <= 0 then
            entity._staggerUntil = math.max(entity._staggerUntil or 0, now() + 0.6)
        end
        return
    end
    -- last resort: reduce Health slightly to reflect guard break
    entity.Health = math.max(0, (entity.Health or 0) - math.floor(amt * 0.2))
end

-- Apply HP and posture damage according to DamageCalculator result
local function applyDamageResults(attacker, defender, res)
    if not isEntity(defender) or type(res) ~= "table" then return end
    if res.hpToDefender and type(res.hpToDefender) == "number" then
        defender.Health = math.max(0, (defender.Health or 0) - res.hpToDefender)
    end
    if res.postureToDefender and type(res.postureToDefender) == "number" then
        if defender.Posture ~= nil then
            defender.Posture = math.clamp((defender.Posture or Constants.POSTURE_MAX) - res.postureToDefender, 0, Constants.POSTURE_MAX)
            if defender.Posture <= 0 then
                defender._staggerUntil = math.max(defender._staggerUntil or 0, now() + 1.0)
            end
        else
            -- fallback: reduce Shield/Guard first, then Health if none
            CombatService.ApplyGuardDamage(defender, res.postureToDefender)
        end
    end
    if res.postureToAttacker and type(res.postureToAttacker) == "number" then
        if attacker and attacker.Posture ~= nil then
            attacker.Posture = math.clamp((attacker.Posture or Constants.POSTURE_MAX) - res.postureToAttacker, 0, Constants.POSTURE_MAX)
            if attacker.Posture <= 0 then
                attacker._staggerUntil = math.max(attacker._staggerUntil or 0, now() + 1.0)
            end
        else
            CombatService.ApplyGuardDamage(attacker or {}, res.postureToAttacker)
        end
    end
end

-- ProcessAttack(attackerEntity, targetEntity, weaponTable)
-- Expects simple tables and returns a result table describing what happened.
-- This function mutates attackerEntity and targetEntity in-place (authoritative).
function CombatService.ProcessAttack(attackerEntity, targetEntity, weaponTable)
    if not isEntity(attackerEntity) or not isEntity(targetEntity) then
        error("ProcessAttack requires attacker and target entity tables")
    end
    local weapon = WeaponData.Normalize(weaponTable or {})
    local attackTime = now()

    -- Determine if defender attempted parry (best-effort): try common fields
    local parryOutcome
    if type(targetEntity.parryIntentTime) == "number" then
        parryOutcome = GuardParry.ResolveParry(targetEntity, attackTime)
    elseif type(targetEntity._parryIntentTime) == "number" then
        -- compatibility with other naming
        targetEntity.parryIntentTime = targetEntity._parryIntentTime
        parryOutcome = GuardParry.ResolveParry(targetEntity, attackTime)
    end

    -- If parry was successful, calculate parry effect
    if parryOutcome and parryOutcome.outcome == "PARRY" then
        -- apply parry posture penalty to defender (they used posture to parry)
        if parryOutcome.posturePenalty and type(parryOutcome.posturePenalty) == "number" then
            if targetEntity.Posture ~= nil then
                targetEntity.Posture = math.clamp((targetEntity.Posture or Constants.POSTURE_MAX) - parryOutcome.posturePenalty, 0, Constants.POSTURE_MAX)
            else
                CombatService.ApplyGuardDamage(targetEntity, parryOutcome.posturePenalty)
            end
        end
        -- parry redirects posture to attacker via DamageCalculator
        local calc = DamageCalculator.Calculate(attackerEntity, targetEntity, weapon, { wasParried = true })
        applyDamageResults(attackerEntity, targetEntity, calc)
        return { outcome = "PARRIED", calc = calc }
    end

    -- Determine if defender is actively guarding
    local isGuarding = false
    if targetEntity.State == "Guarding" or targetEntity.state == "Guarding" or targetEntity.IsGuarding then
        isGuarding = true
    elseif (targetEntity.Shield or targetEntity.Guard or 0) > 0 then
        -- treat as guarding if shield > 0 and defender recently started guarding
        isGuarding = targetEntity._isGuarding == true
    end

    -- If both attacker and defender are striking at similar times, resolve clash
    if attackerEntity._lastAttackTime and targetEntity._lastAttackTime then
        local aHit = { hitTime = attackerEntity._lastAttackTime or attackTime, weapon = weapon }
        local dHit = { hitTime = targetEntity._lastAttackTime or attackTime, weapon = targetEntity.weapon or {} }
        local clash = ClashResolver.Resolve(aHit, dHit)
        if clash and clash.outcome then
            local calc = DamageCalculator.Calculate(attackerEntity, targetEntity, weapon, { clashOutcome = clash.outcome })
            applyDamageResults(attackerEntity, targetEntity, calc)
            return { outcome = "CLASH", clash = clash, calc = calc }
        end
    end

    -- Normal hit path: compute damage with guard flag
    local calc = DamageCalculator.Calculate(attackerEntity, targetEntity, weapon, { isGuarding = isGuarding })
    applyDamageResults(attackerEntity, targetEntity, calc)

    -- If defender posture reached zero or guard broke, set stagger
    if (targetEntity.Posture and targetEntity.Posture <= 0) or targetEntity._isGuardBroken then
        targetEntity._staggerUntil = math.max(targetEntity._staggerUntil or 0, now() + 1.0)
    end

    -- update attacker last attack time for potential clash resolution in future
    attackerEntity._lastAttackTime = attackTime

    return { outcome = "HIT", calc = calc }
end

-- Simple helper to validate lock-on request server-side
function CombatService.ValidateLockOn(attackerPos, targetPos, attackerForward)
    return TargetValidator.ValidateLockOn(attackerPos, targetPos, attackerForward)
end

-- Sprint integration helpers
function CombatService.CanStartSprint(playerState)
    if not isEntity(playerState) then return false end
    return Sprint.CanStart(playerState)
end
function CombatService.TickSprint(playerState, dt)
    if not isEntity(playerState) then return false end
    return Sprint.Tick(playerState, dt)
end
-- =====================================================
-- POSTURE / STAGGER HELPERS (FOR DEATHBLOW)
-- =====================================================
function CombatService.IsPostureBroken(entity)
    if not isEntity(entity) then return false end

    -- Posture-based system
    if entity.Posture ~= nil then
        return entity.Posture <= 0
    end

    -- Shield / Guard fallback
    if entity.Shield ~= nil then
        return entity.Shield <= 0
    end
    if entity.Guard ~= nil then
        return entity.Guard <= 0
    end

    -- Time-based stagger fallback
    if entity._staggerUntil and entity._staggerUntil > now() then
        return true
    end

    return false
end
-- =====================================================
-- DEATHBLOW (SEKIRO-STYLE EXECUTION)
-- =====================================================
function CombatService.PerformDeathblow(attackerEntity, targetEntity)
    if not isEntity(attackerEntity) or not isEntity(targetEntity) then
        return false
    end

    -- Target must be posture-broken or staggered
    if not CombatService.IsPostureBroken(targetEntity) then
        return false
    end

    -- Boss / multi-phase handling
    if type(targetEntity.Lives) == "number" and targetEntity.Lives > 1 then
        targetEntity.Lives -= 1

        -- Reset posture & stagger for next phase
        targetEntity.Posture = Constants.POSTURE_MAX
        targetEntity._staggerUntil = now() + 0.8

        return {
            outcome = "DEATHBLOW_PHASE",
            remainingLives = targetEntity.Lives
        }
    end

    -- Normal enemy: instant kill
    targetEntity.Health = 0
    targetEntity._isDead = true
    targetEntity._deathblowBy = attackerEntity

    return {
        outcome = "DEATHBLOW_KILL"
    }
end

return CombatService
