-- MoveState.lua
-- Move state: Character is moving (walking/running)

local BaseState = require(script.Parent.BaseState)

local MoveState = setmetatable({}, BaseState)
MoveState.__index = MoveState

function MoveState.new()
	local self = setmetatable(BaseState.new("Move"), MoveState)
	self.allowedTransitions = {
		["Idle"] = true,
		["Attack"] = true,
		["Block"] = true,
		["Parry"] = true,
		["Dash"] = true,
		["HitStun"] = true,
		["Death"] = true,
	}
	return self
end

function MoveState:Enter(prevState, context)
	-- Ensure movement is enabled
	if context.Controllers and context.Controllers.MovementController then
		context.Controllers.MovementController:Enable()
	end
end

function MoveState:Exit(nextState, context)
	-- Movement remains enabled unless transitioning to locked states
end

function MoveState:Update(dt, context)
	-- Handle movement logic, e.g., update velocity based on input
	if context.Humanoid then
		-- Movement updates here
	end
end

return MoveState
