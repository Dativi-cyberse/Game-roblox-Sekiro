-- AttackState.lua
-- Mugen-style combo attack state

local BaseState = require(script.Parent.BaseState)
local AttackState = setmetatable({}, BaseState)
AttackState.__index = AttackState

local ATTACK_DURATION = 0.45
local COMBO_BUFFER = 0.4
local MAX_COMBO = 4
local LUNGE_SPEEDS = { 50, 30, 30, 70 } -- Strong opener, light mids, heavy finisher

function AttackState.new()
	local self = setmetatable(BaseState.new("Attack"), AttackState)

	self.allowedTransitions = {
		Attack = true,
		Idle = true,
		HitStun = true,
		Death = true,
	}

	return self
end

function AttackState:Enter(prevState, context)
	local now = os.clock()

	self.endTime = now + ATTACK_DURATION
	self.bufferTime = self.endTime - COMBO_BUFFER

	context.comboQueued = false
	context.attackRequested = false -- Fix: Clear intent on entry to prevent immediate re-trigger

	if prevState and prevState.name == "Attack" then
		context.comboIndex = math.min((context.comboIndex or 1) + 1, MAX_COMBO)
	else
		context.comboIndex = 1
	end

	if context.AnimationController then
		context.AnimationController:PlayAttack(context.comboIndex)
	end

	-- [MUGEN MOVEMENT] Forward Lunge Impulse
	if context.Root then
		local speed = LUNGE_SPEEDS[context.comboIndex] or 30
		local forward = context.Root.CFrame.LookVector
		-- Apply horizontal velocity, preserve vertical (gravity)
		local currentY = context.Root.AssemblyLinearVelocity.Y
		context.Root.AssemblyLinearVelocity = Vector3.new(forward.X * speed, currentY, forward.Z * speed)
	end
end

function AttackState:HandleInput(input, context)
	if input == "M1" then
		if os.clock() >= self.bufferTime then
			context.comboQueued = true
		end
	end
end

function AttackState:Update(_, context)
	if os.clock() < self.endTime then
		return
	end

	if context.comboQueued and context.comboIndex < MAX_COMBO then
		context.comboQueued = false
		context.StateMachine:ChangeState(AttackState.new())
		return -- Fix: Prevent fallthrough
	else
		context.comboIndex = 1
		context.StateMachine:ChangeState(context.States.Idle)
		return -- Fix: Prevent fallthrough
	end
end

function AttackState:Exit() end

return AttackState
