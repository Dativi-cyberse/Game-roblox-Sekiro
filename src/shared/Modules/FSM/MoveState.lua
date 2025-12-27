local BaseState = require(script.Parent.BaseState)

local MoveState = setmetatable({}, BaseState)
MoveState.__index = MoveState

function MoveState.new()
	return setmetatable(BaseState.new("Move"), MoveState)
end

function MoveState:Enter(context)
	if not context.weaponEquipped then return end
	context.AnimationController:PlaySprint()
end

function MoveState:Update(_, context)
	if not context.weaponEquipped then return end

	local mag = context.Humanoid.MoveDirection.Magnitude
	if mag == 0 and context.previousMoveMagnitude > 0 then
		context.StateMachine:ChangeState(context.States.Idle)
	end
	context.previousMoveMagnitude = mag
end

return MoveState
 