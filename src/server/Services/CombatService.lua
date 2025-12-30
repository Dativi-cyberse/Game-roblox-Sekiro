-- CombatService.server.lua
-- Server-authoritative combat orchestration.
-- SINGLE SOURCE OF TRUTH for damage, posture, parry, clash.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared:WaitForChild("Modules")

local Constants = require(Modules.Core.Constants)
local DamageCalculator = require(Modules.Combat.DamageCalculator)
local GuardParry = require(Modules.Combat.GuardParry)
local ClashResolver = require(Modules.Combat.ClashResolver)
local ShieldSystem = require(Modules.Combat.ShieldSystem)
local Sprint = require(Modules.Movement.Sprint)
local TargetValidator = require(Modules.Targeting.TargetValidator)
local WeaponData = require(Modules.Weapons.WeaponData)

local CombatService = {}

CombatService.Config = {
	Weapons = {},
}

local function now()
	return os.clock()
end

local function isEntity(e)
	return type(e) == "table"
end

-- =========================
-- GUARD / POSTURE DAMAGE
-- =========================
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

	if entity.Posture ~= nil then
		entity.Posture = math.clamp(
			(entity.Posture or Constants.POSTURE_MAX) - amt,
			0,
			Constants.POSTURE_MAX
		)
		if entity.Posture <= 0 then
			entity._staggerUntil = math.max(entity._staggerUntil or 0, now() + 0.6)
		end
		return
	end

	entity.Health = math.max(0, (entity.Health or 0) - math.floor(amt * 0.2))
end

-- =========================
-- APPLY DAMAGE RESULTS
-- =========================
local function applyDamageResults(attacker, defender, res)
	if not isEntity(defender) or type(res) ~= "table" then return end

	if res.hpToDefender and type(res.hpToDefender) == "number" then
		defender.Health = math.max(0, (defender.Health or 0) - res.hpToDefender)
	end

	if res.postureToDefender and type(res.postureToDefender) == "number" then
		if defender.Posture ~= nil then
			defender.Posture = math.clamp(
				(defender.Posture or Constants.POSTURE_MAX) - res.postureToDefender,
				0,
				Constants.POSTURE_MAX
			)
			if defender.Posture <= 0 then
				defender._staggerUntil = math.max(defender._staggerUntil or 0, now() + 1.0)
			end
		else
			CombatService.ApplyGuardDamage(defender, res.postureToDefender)
		end
	end

	if res.postureToAttacker and type(res.postureToAttacker) == "number" then
		if attacker and attacker.Posture ~= nil then
			attacker.Posture = math.clamp(
				(attacker.Posture or Constants.POSTURE_MAX) - res.postureToAttacker,
				0,
				Constants.POSTURE_MAX
			)
			if attacker.Posture <= 0 then
				attacker._staggerUntil = math.max(attacker._staggerUntil or 0, now() + 1.0)
			end
		else
			CombatService.ApplyGuardDamage(attacker or {}, res.postureToAttacker)
		end
	end
end

-- =========================
-- MAIN ATTACK ENTRY
-- =========================
function CombatService.ProcessAttack(attackerEntity, targetEntity, weaponTable)
	print("[CombatService] ProcessAttack", attackerEntity, "->", targetEntity)

	if not isEntity(attackerEntity) or not isEntity(targetEntity) then
		error("ProcessAttack requires attacker and target entity tables")
	end

	local weapon = WeaponData.Normalize(weaponTable or {})
	local attackTime = now()

	-- =========================
	-- PARRY CHECK
	-- =========================
	local parryOutcome
	if type(targetEntity.parryIntentTime) == "number" then
		parryOutcome = GuardParry.ResolveParry(targetEntity, attackTime)
	end

	if parryOutcome and parryOutcome.outcome == "PARRY" then
		if parryOutcome.posturePenalty and type(parryOutcome.posturePenalty) == "number" then
			if targetEntity.Posture ~= nil then
				targetEntity.Posture = math.clamp(
					(targetEntity.Posture or Constants.POSTURE_MAX) - parryOutcome.posturePenalty,
					0,
					Constants.POSTURE_MAX
				)
			else
				CombatService.ApplyGuardDamage(targetEntity, parryOutcome.posturePenalty)
			end
		end

		local calc = DamageCalculator.Calculate(
			attackerEntity,
			targetEntity,
			weapon,
			{ wasParried = true }
		)

		applyDamageResults(attackerEntity, targetEntity, calc)

		return { outcome = "PARRIED", calc = calc }
	end

	-- =========================
	-- GUARD CHECK
	-- =========================
	local isGuarding = false
	if targetEntity.State == "Guarding"
		or targetEntity.state == "Guarding"
		or targetEntity.IsGuarding then
		isGuarding = true
	elseif (targetEntity.Shield or targetEntity.Guard or 0) > 0 then
		isGuarding = targetEntity._isGuarding == true
	end

	-- =========================
	-- CLASH CHECK
	-- =========================
	if attackerEntity._lastAttackTime and targetEntity._lastAttackTime then
		local aHit = { hitTime = attackerEntity._lastAttackTime, weapon = weapon }
		local dHit = { hitTime = targetEntity._lastAttackTime, weapon = targetEntity.weapon or {} }

		local clash = ClashResolver.Resolve(aHit, dHit)
		if clash and clash.outcome then
			local calc = DamageCalculator.Calculate(
				attackerEntity,
				targetEntity,
				weapon,
				{ clashOutcome = clash.outcome }
			)

			applyDamageResults(attackerEntity, targetEntity, calc)

			return { outcome = "CLASH", clash = clash, calc = calc }
		end
	end

	-- =========================
	-- NORMAL HIT
	-- =========================
	local calc = DamageCalculator.Calculate(
		attackerEntity,
		targetEntity,
		weapon,
		{ isGuarding = isGuarding }
	)

	applyDamageResults(attackerEntity, targetEntity, calc)

	if (targetEntity.Posture and targetEntity.Posture <= 0) or targetEntity._isGuardBroken then
		targetEntity._staggerUntil = math.max(targetEntity._staggerUntil or 0, now() + 1.0)
	end

	attackerEntity._lastAttackTime = attackTime

	print(
		"[CombatService] Damage applied",
		"HP =", targetEntity.Health,
		"Posture =", targetEntity.Posture
	)

	return { outcome = "HIT", calc = calc }
end

-- =========================
-- LOCK-ON / MOVEMENT
-- =========================
function CombatService.ValidateLockOn(attackerPos, targetPos, attackerForward)
	return TargetValidator.ValidateLockOn(attackerPos, targetPos, attackerForward)
end

function CombatService.CanStartSprint(playerState)
	if not isEntity(playerState) then return false end
	return Sprint.CanStart(playerState)
end

function CombatService.TickSprint(playerState, dt)
	if not isEntity(playerState) then return false end
	return Sprint.Tick(playerState, dt)
end

-- =========================
-- POSTURE / DEATHBLOW
-- =========================
function CombatService.IsPostureBroken(entity)
	if not isEntity(entity) then return false end

	if entity.Posture ~= nil then
		return entity.Posture <= 0
	end

	if entity.Shield ~= nil then
		return entity.Shield <= 0
	end

	if entity.Guard ~= nil then
		return entity.Guard <= 0
	end

	if entity._staggerUntil and entity._staggerUntil > now() then
		return true
	end

	return false
end

function CombatService.PerformDeathblow(attackerEntity, targetEntity)
	if not isEntity(attackerEntity) or not isEntity(targetEntity) then
		return { outcome = "ERROR", reason = "Invalid entities" }
	end

	if not CombatService.IsPostureBroken(targetEntity) then
		return { outcome = "ERROR", reason = "Target posture not broken" }
	end

	if targetEntity.IsBoss
		and type(targetEntity.Lives) == "number"
		and targetEntity.Lives > 1 then

		targetEntity.Lives -= 1

		local damage = (targetEntity.MaxHealth or 100) * 0.2
		targetEntity.Health = math.max(0, targetEntity.Health - damage)

		targetEntity.Posture = targetEntity.MaxPosture or 100
		targetEntity._staggerUntil = now() + 1.5

		return {
			outcome = "DEATHBLOW_PHASE",
			remainingLives = targetEntity.Lives,
		}
	end

	targetEntity.Health = 0
	targetEntity._isDead = true
	targetEntity.State = "Dead"

	return { outcome = "DEATHBLOW_KILL" }
end

return CombatService
