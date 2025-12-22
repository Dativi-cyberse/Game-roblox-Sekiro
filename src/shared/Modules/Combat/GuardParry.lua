local Constants = require(script.Parent.Parent.Core.Constants)

local GuardParry = {}

-- Record a parry intent on the player's state (server should call this when client signals)
function GuardParry.RecordParryIntent(playerState)
	if not playerState then return end
	playerState:RecordParryIntent()
end

-- Resolve parry when an attack arrives. Returns:
-- { outcome = "PARRY" | "FAILED" | "NONE", posturePenalty = number }
function GuardParry.ResolveParry(defenderState, attackTime)
	if not defenderState or not attackTime then
		return { outcome = "NONE", posturePenalty = 0 }
	end

	local intent = defenderState.parryIntentTime or 0
	local window = Constants.PARRY_WINDOW + Constants.PARRY_GRACE
	local dt = math.abs(intent - attackTime)

	if intent > 0 and dt <= window then
		-- successful parry
		-- apply light posture damage to defender (parry consumes posture but blocks hit)
		local posturePenalty = math.ceil(Constants.POSTURE_MAX * 0.03)
		defenderState.parryIntentTime = 0
		return { outcome = "PARRY", posturePenalty = posturePenalty }
	end

	-- if player attempted parry but missed, apply failed parry penalty
	if intent > 0 then
		defenderState.parryIntentTime = 0
		return { outcome = "FAILED", posturePenalty = Constants.FAILED_PARRY_POSTURE_PENALTY }
	end

	return { outcome = "NONE", posturePenalty = 0 }
end

return GuardParry
