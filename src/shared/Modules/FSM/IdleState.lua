-- IdleState.lua
-- Safe idle state with weapon awareness

local BaseState = require(script.Parent.BaseState)
local IdleState = setmetatable({}, BaseState)
IdleState.__index = IdleState

function IdleState.new()
	local self = setmetatable(BaseState.new("Idle"), IdleState)

	self.allowedTransitions = {
		Move = true,
		Attack = true,
		Block = true,
		Dash = true,
		Parry = true,
		HitStun = true,
		Death = true,
	}

	return self
end

function IdleState:Enter(_, context)
	if not context then return end

	-- No weapon → let Roblox Animate run
	if not context.weaponEquipped then
		return
	end

	if context.AnimationController then
		context.AnimationController:PlayIdle()
	end
end

function IdleState:Update(dt, context)
	if context.attackRequested then
		context.StateMachine:ChangeState(context.States.Attack)
		return
	end

	if context.blockRequested then
		context.StateMachine:ChangeState(context.States.Block)
		return
	end

	if context.parryRequested then
		context.StateMachine:ChangeState(context.States.Parry)
		return
	end

	if context.Humanoid and context.Humanoid.MoveDirection.Magnitude > 0.1 then
		if context.weaponEquipped then
			context.StateMachine:ChangeState(context.States.Move)
			return
		end
	end

	-- [NPC FIX] Transition to Move if target exists
	if context.isNPC and context.moveTarget then
		context.StateMachine:ChangeState(context.States.Move)
		return
	end
end
function IdleState:Exit() end

return IdleState
