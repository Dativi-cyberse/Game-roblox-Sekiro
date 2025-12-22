local Constants = require(script.Parent.Parent.Core.Constants)

local TargetValidator = {}

-- Validate lock-on using positions and forward vector (server-side)
-- attackerPos, targetPos: Vector3
-- attackerForward: Vector3 (unit)
function TargetValidator.ValidateLockOn(attackerPos, targetPos, attackerForward)
	if not attackerPos or not targetPos or not attackerForward then
		return false
	end
	local offset = targetPos - attackerPos
	local dist = offset.Magnitude
	if dist > Constants.LOCKON_MAX_DISTANCE then
		return false
	end
	local dir = offset.Unit
	local dot = attackerForward:Dot(dir)
	local angle = math.acos(math.clamp(dot, -1, 1))
	if angle > Constants.LOCKON_MAX_ANGLE then
		return false
	end
	return true
end

return TargetValidator
