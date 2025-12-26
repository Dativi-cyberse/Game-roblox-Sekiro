-- IdleState.lua
-- Idle state: Character is standing still, ready for actions

local BaseState = require(script.Parent.BaseState)

local IdleState = setmetatable({}, BaseState)
IdleState.__index = IdleState

function IdleState.new()
	local self = setmetatable(BaseState.new("Idle"), IdleState)
	self.allowedTransitions = {
		["Move"] = true,
		["Attack"] = true,
		["Block"] = true,
		["Parry"] = true,
		["Dash"] = true,
		["HitStun"] = true,
		["Death"] = true,
	}
	return self
end

function IdleState:Enter(prevState, context)
	-- Ensure idle animation is playing
	if context.AnimationController then
		context.AnimationController:PlayIdle()
	end
end

function IdleState:Exit(nextState, context)
	-- Transitioning out of idle
end

function IdleState:Update(dt, context)
	-- Check for input to transition to other states
end

return IdleState
