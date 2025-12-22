local Constants = require(script.Parent.Parent.Core.Constants)
local WeaponData = require(script.Parent.Parent.Weapons.WeaponData)

local DamageCalculator = {}

-- Calculate damage given attacker/defender state objects and weapon data.
-- attackerState / defenderState are expected to be PlayerState-like objects.
-- weapon may be raw table or normalized via WeaponData.Normalize
-- options: {isGuarding = bool, wasParried = bool, clashOutcome = "ATTACKER_WIN"|"DEFENDER_WIN"|"NEUTRAL"}
function DamageCalculator.Calculate(attackerState, defenderState, weapon, options)
	options = options or {}
	local w = WeaponData.Normalize(weapon)

	local hpDamage = w.baseDamage * Constants.BASE_DAMAGE_MULTIPLIER
	local postureDamage = w.postureDamage * Constants.POSTURE_DAMAGE_MULTIPLIER

	if options.isGuarding then
		hpDamage = hpDamage * Constants.GUARD_HP_REDUCTION * (w.guardMultiplier or 1)
		postureDamage = postureDamage * Constants.GUARD_POSTURE_REDUCTION
	end

	if options.wasParried then
		-- successful parry redirects posture back to attacker
		local attackerPosture = math.ceil(postureDamage * 1.5)
		return {
			hpToDefender = 0,
			postureToDefender = 0,
			postureToAttacker = attackerPosture,
			hpToAttacker = 0,
			reason = "parried",
		}
	end

	if options.clashOutcome == "NEUTRAL" then
		-- both hit but neutral; reduce effects
		hpDamage = math.floor(hpDamage * 0.5)
		postureDamage = math.floor(postureDamage * 0.75)
	elseif options.clashOutcome == "DEFENDER_WIN" then
		-- attacker takes increased posture
		local attackerPosture = math.ceil(postureDamage * 1.4)
		return {
			hpToDefender = 0,
			postureToDefender = 0,
			postureToAttacker = attackerPosture,
			hpToAttacker = 0,
			reason = "clash_defender_win",
		}
	elseif options.clashOutcome == "ATTACKER_WIN" then
		-- defender gets full damage below
	end

	return {
		hpToDefender = math.max(0, math.floor(hpDamage)),
		postureToDefender = math.max(0, math.floor(postureDamage)),
		postureToAttacker = 0,
		hpToAttacker = 0,
		reason = "hit",
	}
end

return DamageCalculator
