-- DeathState.lua
-- Death state: Character is dead, locks all transitions

local BaseState = require(script.Parent.BaseState)

local DeathState = setmetatable({}, BaseState)
DeathState.__index = DeathState

function DeathState.new()
	local self = setmetatable(BaseState.new("Death"), DeathState)
	self.allowedTransitions = {
		-- Death state is terminal, no transitions allowed
	}
	return self
end

function DeathState:Enter(prevState, context)
	-- Play death animation
	if context.AnimationController then
		context.AnimationController:PlayDeath()
	end
	-- Disable all controls
	if context.Controllers then
		for _, controller in pairs(context.Controllers) do
			if controller.Disable then
				controller:Disable()
			end
		end
	end
end

function DeathState:Exit(nextState, context)
	-- Should not exit death state
end

function DeathState:Update(dt, context)
	-- No updates, character is dead
end

return DeathState
