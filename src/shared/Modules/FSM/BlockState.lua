local BaseState = require(script.Parent.BaseState)

local BlockState = setmetatable({}, BaseState)
BlockState.__index = BlockState

local GUARD_SPEED = 8

function BlockState.new()
	local self = setmetatable(BaseState.new("Block"), BlockState)
	self.allowedTransitions = {
		Idle = true,
		Move = true,
		HitStun = true,
		Death = true,
	}
	return self
end

function BlockState:Enter(prevState, context)
	if not context.weaponEquipped then return end
	if context.Humanoid then
		context.Humanoid.WalkSpeed = GUARD_SPEED
	end
	
	-- Sync Guard State to Server
	if context.Root and context.Root.Parent then
		context.Root.Parent:SetAttribute("IsGuarding", true)
	end

	if context.AnimationController then
		context.AnimationController:PlayGuard()
	end
end

function BlockState:Update(dt, context)
	if not context.blockRequested then
		context.StateMachine:ChangeState(context.States.Idle)
		return
	end

	-- Allow moving while guarding (Transition to MoveState)
	if context.Humanoid and context.Humanoid.MoveDirection.Magnitude > 0.1 then
		context.StateMachine:ChangeState(context.States.Move)
	end

	-- [NPC FIX] Allow moving out of block state via moveTarget
	if context.isNPC and context.moveTarget then
		context.StateMachine:ChangeState(context.States.Move)
	end
end

function BlockState:Exit(nextState, context)
	if context and context.Humanoid and nextState.name ~= "Move" then
		context.Humanoid.WalkSpeed = 16
	end
	
	-- Clear attribute if not transitioning to Move (MoveState handles it if guarding)
	if nextState.name ~= "Move" and context.Root and context.Root.Parent then
		context.Root.Parent:SetAttribute("IsGuarding", false)
	end
end

return BlockState
