local BaseState = require(script.Parent.BaseState)

local MoveState = setmetatable({}, BaseState)
MoveState.__index = MoveState

local WALK_SPEED = 16
local SPRINT_SPEED = 24
local GUARD_SPEED = 10

function MoveState.new()
	local self = setmetatable(BaseState.new("Move"), MoveState)
	self.allowedTransitions = {
		Idle = true,
		Attack = true,
		Block = true,
		Dash = true,
		HitStun = true,
		Death = true,
	}
	return self
end

function MoveState:Enter(prev, context)
	if context.weaponEquipped and context.AnimationController then
		context.AnimationController:PlayMove()
	end
end

function MoveState:Update(_, context)
	if context.attackRequested then
		context.StateMachine:ChangeState(context.States.Attack)
		return
	end

	if context.blockRequested then
		context.StateMachine:ChangeState(context.States.Block)
		return
	end

	-- [FIX] Handle movement speed modifiers
	local targetSpeed = WALK_SPEED
	if context.sprintRequested then
		targetSpeed = SPRINT_SPEED
	end
	context.Humanoid.WalkSpeed = targetSpeed

	if context.Humanoid.MoveDirection.Magnitude < 0.05 then
		context.StateMachine:ChangeState(context.States.Idle)
	end
end

function MoveState:Exit(nextState) end

return MoveState
