local Constants = require(script.Parent.Parent.Core.Constants)

local ShieldSystem = {}

-- Tick guard consumption. Consumes stamina and drains posture while guarding.
-- Returns false if guard should end (not enough stamina or staggered), true otherwise.
function ShieldSystem.TickGuard(playerState, dt)
	if not playerState or dt <= 0 then return false end
	local staminaDrain = Constants.GUARD_STAMINA_DRAIN_PER_SECOND * dt
	local postureDrain = Constants.GUARD_POSTURE_DRAIN_PER_SECOND * dt

	playerState:ConsumeStamina(staminaDrain)
	playerState:AddPosture(postureDrain)

	if playerState.stamina <= 0 or playerState:IsStaggered() then
		playerState:EndGuard()
		return false
	end
	return true
end

-- Called when guard is forcibly broken (e.g., heavy hit)
function ShieldSystem.BreakGuard(playerState, breakDuration)
	playerState:SetStagger(breakDuration or 1.0)
	playerState:EndGuard()
end

return ShieldSystem
