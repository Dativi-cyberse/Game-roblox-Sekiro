local BaseState = require(script.Parent.BaseState)

local IdleState = setmetatable({}, BaseState)
IdleState.__index = IdleState

function IdleState.new()
	return setmetatable(BaseState.new("Idle"), IdleState)
end

function IdleState:Enter(context)
	if context.weaponEquipped then
		-- 🔒 KHÓA Animate để Roblox không ghi đè
		if context.Animate then
			context.Animate.Disabled = true
		end

		-- play combat idle
		context.AnimationController:PlayIdle()
	else
		-- tay không → trả Animate lại cho Roblox
		if context.Animate then
			context.Animate.Disabled = false
		end
	end
end


function IdleState:Update(_, context)
	if not context.weaponEquipped then return end

	local mag = context.Humanoid.MoveDirection.Magnitude
	if mag > 0 and context.previousMoveMagnitude == 0 then
		context.StateMachine:ChangeState(context.States.Move)
	end
	context.previousMoveMagnitude = mag
end

return IdleState
