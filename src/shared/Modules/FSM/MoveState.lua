local BaseState = require(script.Parent.BaseState)

local MoveState = setmetatable({}, BaseState)
MoveState.__index = MoveState

local STOP_THRESHOLD = 0.05

function MoveState.new()
	return setmetatable(BaseState.new("Move"), MoveState)
end

function MoveState:Enter(context)
	-- CHỈ play combat animation nếu đang cầm vũ khí
	if context.weaponEquipped and context.AnimationController then
		context.AnimationController:PlaySprint()
	end
end

function MoveState:Update(_, context)
	local humanoid = context.Humanoid
	if not humanoid then return end

	local mag = humanoid.MoveDirection.Magnitude

	-- 🔥 CHỈ THOÁT MOVE KHI THỰC SỰ DỪNG
	if mag <= STOP_THRESHOLD then
		context.StateMachine:ChangeState(context.States.Idle)
	end
end

function MoveState:Exit(context)
	-- KHÔNG stop animation ở đây
end

return MoveState
