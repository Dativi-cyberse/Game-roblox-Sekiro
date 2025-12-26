-- DashState.lua
-- Dash state: Character is dashing

local BaseState = require(script.Parent.BaseState)

local DashState = setmetatable({}, BaseState)
DashState.__index = DashState

function DashState.new()
	local self = setmetatable(BaseState.new("Dash"), DashState)
	self.allowedTransitions = {
		["Idle"] = true,
		["Move"] = true,
		["Attack"] = true, -- Can cancel into attack
		["HitStun"] = true,
		["Death"] = true,
	}
	return self
end

function DashState:Enter(prevState, context)
	-- Start dash
	if context.Controllers and context.Controllers.DashController then
		context.Controllers.DashController:StartDash()
	end
end

function DashState:Exit(nextState, context)
	-- End dash
	if context.Controllers and context.Controllers.DashController then
		context.Controllers.DashController:StopDash()
	end
end

function DashState:Update(dt, context)
	-- Update dash progress
	if context.Controllers and context.Controllers.DashController then
		if context.Controllers.DashController:IsDashFinished() then
			-- Transition back to Idle or Move
		end
	end
end

return DashState
