local Constants = require(script.Parent.Parent.Core.Constants)
local PlayerState = require(script.Parent.Parent.Core.PlayerState)
local WeaponData = require(script.Parent.Parent.Weapons.WeaponData)
local DamageCalculator = require(script.Parent.Combat.DamageCalculator)
local GuardParry = require(script.Parent.Combat.GuardParry)
local ClashResolver = require(script.Parent.Combat.ClashResolver)
local ShieldSystem = require(script.Parent.Combat.ShieldSystem)

local CombatTestHarness = {}

local function dbg(...)
    if Constants.DEBUG then
        print("[CombatTestHarness]", ...)
    end
end

-- Run a set of deterministic unit-like tests and return results table.
function CombatTestHarness.Run()
    local results = {}
    local now = tick()

    -- create two players
    local atk = PlayerState.new({stamina = 100, posture = Constants.POSTURE_MAX})
    local def = PlayerState.new({stamina = 100, posture = Constants.POSTURE_MAX})

    -- weapons
    local swordA = WeaponData.Normalize({id = "swordA", baseDamage = 20, postureDamage = 12})
    local swordB = WeaponData.Normalize({id = "swordB", baseDamage = 14, postureDamage = 9})

    -- Test 1: Simple hit (no guard)
    do
        local attackTime = now + 0.01
        local calc = DamageCalculator.Calculate(atk, def, swordA, { isGuarding = false })
        results.simpleHit = { calc = calc }
        dbg("SimpleHit:", calc.hpToDefender, calc.postureToDefender)
    end

    -- Test 2: Guard reduces hp and posture
    do
        def.stamina = 50
        def:StartGuard()
        local calc = DamageCalculator.Calculate(atk, def, swordA, { isGuarding = true })
        results.guardHit = { calc = calc }
        dbg("GuardHit:", calc.hpToDefender, calc.postureToDefender)
        def:EndGuard()
    end

    -- Test 3: Parry success
    do
        -- simulate defender intent timed exactly with attack
        local attackTime = now + 0.05
        def.parryIntentTime = attackTime -- simulate perfect timing
        local parry = GuardParry.ResolveParry(def, attackTime)
        local calc
        if parry.outcome == "PARRY" then
            calc = DamageCalculator.Calculate(atk, def, swordA, { wasParried = true })
        else
            calc = DamageCalculator.Calculate(atk, def, swordA, {})
        end
        results.parry = { parry = parry, calc = calc }
        dbg("Parry:", parry.outcome, parry.posturePenalty)
    end

    -- Test 4: Failed parry penalty
    do
        local attackTime = now + 0.1
        def.parryIntentTime = now + 0.0 -- a stale intent
        local parry = GuardParry.ResolveParry(def, attackTime)
        results.failedParry = { parry = parry }
        dbg("FailedParry:", parry.outcome, parry.posturePenalty)
    end

    -- Test 5: Clash neutral
    do
        local aHit = { hitTime = now + 0.2, weapon = swordA, state = atk }
        local dHit = { hitTime = now + 0.2 + 0.0001, weapon = swordB, state = def }
        local clash = ClashResolver.Resolve(aHit, dHit)
        results.clashNeutral = clash
        dbg("ClashNeutral:", clash.outcome, clash.postureToAttacker, clash.postureToDefender)
    end

    -- Test 6: Clash attacker wins
    do
        local aHit = { hitTime = now + 0.3, weapon = swordA, state = atk }
        local dHit = { hitTime = now + 0.4, weapon = swordB, state = def }
        local clash = ClashResolver.Resolve(aHit, dHit)
        results.clashAttackerWin = clash
        dbg("ClashAttackerWin:", clash.outcome, clash.postureToDefender)
    end

    return results
end

return CombatTestHarness
