local Constants = require(script.Parent.Parent.Core.Constants)

local Sprint = {}

-- Try to start sprint. Returns true if sprint allowed.
function Sprint.CanStart(playerState)
	if not playerState then return false end
	if playerState:IsStaggered() then return false end
	if playerState.stamina <= 0 then return false end
	return true
end

-- Tick sprint consumption. Returns whether sprint should continue.
function Sprint.Tick(playerState, dt)
	if not playerState or dt <= 0 then return false end
	local drain = Constants.SPRINT_STAMINA_DRAIN_PER_SECOND * dt
	playerState:ConsumeStamina(drain)
	if playerState.stamina <= 0 then
		return false
	end
	return true
end

return Sprint
