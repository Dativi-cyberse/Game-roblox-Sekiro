local BaseState = require(script.Parent.BaseState)

local MoveState = setmetatable({}, BaseState)
MoveState.__index = MoveState

local WALK_SPEED = 16
local SPRINT_SPEED = 24
local GUARD_SPEED = 8

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
	self.currentAnim = nil -- Reset animation tracker
	self:_UpdateMoveLogic(context)
end

function MoveState:Update(_, context)
	if context.attackRequested then
		context.StateMachine:ChangeState(context.States.Attack)
		return
	end

	self:_UpdateMoveLogic(context)

	-- [NPC FIX] Handle AI Movement
	if context.isNPC and context.moveTarget and context.Humanoid then
		context.Humanoid:MoveTo(context.moveTarget)
	elseif context.isNPC and not context.moveTarget then
		context.StateMachine:ChangeState(context.States.Idle)
		return
	end

	if context.Humanoid.MoveDirection.Magnitude < 0.05 then
		if context.blockRequested then
			context.StateMachine:ChangeState(context.States.Block)
		else
			context.StateMachine:ChangeState(context.States.Idle)
		end
	end
end

function MoveState:_UpdateMoveLogic(context)
	local isGuarding = context.blockRequested
	
	-- Sync Attribute
	if context.Root and context.Root.Parent then
		context.Root.Parent:SetAttribute("IsGuarding", isGuarding)
	end

	-- Determine Speed & Animation
	local targetSpeed = WALK_SPEED
	local desiredAnim = "Move"

	if isGuarding then
		targetSpeed = GUARD_SPEED
		desiredAnim = "Guard"
	elseif context.sprintRequested then
		targetSpeed = SPRINT_SPEED
	end

	context.Humanoid.WalkSpeed = targetSpeed

	-- Play Animation only if changed (Prevent spamming :Play())
	if self.currentAnim ~= desiredAnim then
		self.currentAnim = desiredAnim
		if context.AnimationController and context.weaponEquipped then
			if desiredAnim == "Guard" then
				context.AnimationController:PlayGuard()
			else
				context.AnimationController:PlayMove()
			end
		end
	end
end

function MoveState:Exit(nextState, context)
	-- Clean up attribute if exiting to something other than Block
	if nextState.name ~= "Block" and context.Root and context.Root.Parent then
		context.Root.Parent:SetAttribute("IsGuarding", false)
	end
end

return MoveState
