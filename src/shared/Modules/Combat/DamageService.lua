-- DamageService.lua
-- Calculates health and posture damage based on combat context
-- WHY: Centralizes damage calculation logic for consistency and easy tuning

local CombatConfig = require(script.Parent.Parent.Parent.CombatConfig)

local DamageService = {}

-- =====================================================
-- DAMAGE CALCULATION
-- =====================================================

--- Calculates damage for a standard attack
-- @param attackerState table - Attacker's state
-- @param defenderState table - Defender's state
-- @param attackData table - { isBlocking: boolean, wasParried: boolean, isUnblockable: boolean }
-- @return table - { healthDamage: number, postureDamage: number }
function DamageService.CalculateAttackDamage(attackerState, defenderState, attackData)
	attackData = attackData or {}
	
	local healthDamage = CombatConfig.Attack.BaseDamage
	local postureDamage = CombatConfig.Attack.BasePostureDamage
	
	-- Apply parry effects (parry negates most damage)
	if attackData.wasParried then
		-- Attack was parried - attacker takes posture damage, defender takes minimal cost
		return {
			healthDamage = 0, -- Parried attacks deal no health damage
			postureDamage = 0, -- Posture damage handled separately by ParryService
			toAttacker = {
				healthDamage = 0,
				postureDamage = CombatConfig.Parry.PostureDamage, -- Large posture penalty to attacker
			}
		}
	end
	
	-- Apply block effects
	if attackData.isBlocking then
		-- Blocking reduces health damage but still takes posture damage
		healthDamage = healthDamage * CombatConfig.Block.HealthReduction
		postureDamage = postureDamage * CombatConfig.Block.PostureDamageMultiplier
	end
	
	-- Apply unblockable effects
	if attackData.isUnblockable then
		-- Unblockable attacks bypass block and deal increased posture damage
		if attackData.isBlocking then
			postureDamage = postureDamage * CombatConfig.Block.UnblockableMultiplier
		end
		-- Health damage is not reduced by block
		healthDamage = CombatConfig.Attack.BaseDamage
	end
	
	-- Apply failed parry penalty
	if attackData.failedParry then
		-- Defender attempted parry but missed - take increased damage
		healthDamage = healthDamage * CombatConfig.Parry.FailedHealthDamageMultiplier
		postureDamage = postureDamage + CombatConfig.Parry.FailedPostureDamage
	end
	
	-- Attacker posture cost for attacking
	local attackerPostureCost = CombatConfig.Posture.AttackCost
	if attackData.isBlocking then
		attackerPostureCost = CombatConfig.Posture.BlockedAttackCost
	end
	
	return {
		healthDamage = healthDamage,
		postureDamage = postureDamage,
		toAttacker = {
			healthDamage = 0,
			postureDamage = attackerPostureCost, -- Attacker pays posture cost for attacking
		}
	}
end

--- Calculates damage for a successful parry
-- @param attackerState table - Character who got parried
-- @param defenderState table - Character who parried
-- @return table - Damage results
function DamageService.CalculateParryDamage(attackerState, defenderState)
	local parryResult = {
		toAttacker = {
			healthDamage = 0,
			postureDamage = CombatConfig.Parry.PostureDamage, -- Large posture damage to attacker
		},
		toDefender = {
			healthDamage = 0,
			postureDamage = CombatConfig.Parry.PosturePenalty, -- Small posture cost for parrying
		}
	}
	
	return parryResult
end

--- Applies health damage to a character
-- @param characterState table - Character state object
-- @param amount number - Amount of health damage
function DamageService.ApplyHealthDamage(characterState, amount)
	if not characterState or type(amount) ~= "number" then
		return
	end
	
	characterState.Health = characterState.Health or 100
	characterState.MaxHealth = characterState.MaxHealth or 100
	
	characterState.Health = math.max(0, math.min(
		characterState.Health - amount,
		characterState.MaxHealth
	))
end

return DamageService


