-- DashState.lua
-- Locked dash state (Mugen-style)

local BaseState = require(script.Parent.BaseState)
local DashState = setmetatable({}, BaseState)
DashState.__index = DashState

local DASH_DURATION = 0.25

function DashState.new()
	local self = setmetatable(BaseState.new("Dash"), DashState)

	self.allowedTransitions = {
		Move = true,
		Idle = true,
		HitStun = true,
	}

	return self
end

function DashState:Enter(_, context)
	self.endTime = os.clock() + DASH_DURATION

	if context.AnimationController then
		local moveDir = context.Humanoid and context.Humanoid.MoveDirection
		context.AnimationController:PlayDash(moveDir)
	end

	if context.Controllers and context.Controllers.DashController then
		local moveDir = context.Humanoid and context.Humanoid.MoveDirection
		context.Controllers.DashController:Dash(moveDir)
	end
end

function DashState:Update(_, context)
	if os.clock() >= self.endTime then
		if context.Humanoid and context.Humanoid.MoveDirection.Magnitude > 0.1 then
			context.StateMachine:ChangeState(context.States.Move)
		else
			context.StateMachine:ChangeState(context.States.Idle)
		end
	end
end

function DashState:Exit() end

return DashState
