local Constants = require(script.Parent.Parent.Core.Constants)

local ClashResolver = {}

-- Resolve clashes between two simultaneous hits.
-- attacker and defender are tables:
-- { hitTime = number, weapon = table, state = playerState }
-- Returns: { outcome = "ATTACKER_WIN"|"DEFENDER_WIN"|"NEUTRAL",
--            postureToAttacker = number, postureToDefender = number }
function ClashResolver.Resolve(attacker, defender)
	attacker = attacker or {}
	defender = defender or {}
	local aTime = attacker.hitTime or 0
	local dTime = defender.hitTime or 0

	local dt = math.abs(aTime - dTime)

	if dt <= Constants.CLASH_TOLERANCE then
		-- Neutral clash: both take reduced posture
		local aw = attacker.weapon or {}
		local dw = defender.weapon or {}
		local aPost = math.floor((aw.postureDamage or math.max(1, (aw.baseDamage or 10) * 0.6)) * 0.6)
		local dPost = math.floor((dw.postureDamage or math.max(1, (dw.baseDamage or 10) * 0.6)) * 0.6)
		return { outcome = "NEUTRAL", postureToAttacker = aPost, postureToDefender = dPost }
	end

	if aTime < dTime then
		-- attacker hit earlier: attacker wins clash
		local dPost = math.floor((defender.weapon and (defender.weapon.postureDamage or 8)) or 8)
		return { outcome = "ATTACKER_WIN", postureToAttacker = 0, postureToDefender = dPost }
	else
		local aPost = math.floor((attacker.weapon and (attacker.weapon.postureDamage or 8)) or 8)
		return { outcome = "DEFENDER_WIN", postureToAttacker = aPost, postureToDefender = 0 }
	end
end

return ClashResolver
