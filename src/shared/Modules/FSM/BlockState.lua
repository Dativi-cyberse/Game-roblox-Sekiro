local BaseState = require(script.Parent.BaseState)

local BlockState = setmetatable({}, BaseState)
BlockState.__index = BlockState

function BlockState.new()
	local self = setmetatable(BaseState.new("Block"), BlockState)
	self.allowedTransitions = {
		Idle = true,
		HitStun = true,
		Death = true,
	}
	return self
end

function BlockState:Enter(prevState, context)
	if not context.weaponEquipped then return end
	if context.Humanoid then
		context.Humanoid.WalkSpeed = 0
	end
	if context.AnimationController then
		context.AnimationController:PlayGuard()
	end
end

function BlockState:Update(dt, context)
	if not context.blockRequested then
		context.StateMachine:ChangeState(context.States.Idle)
	end
end

function BlockState:Exit(nextState, context)
	if context and context.Humanoid then
		context.Humanoid.WalkSpeed = 16
	end
end

return BlockState
