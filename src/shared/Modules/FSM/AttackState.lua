local BaseState = require(script.Parent.BaseState)

local AttackState = setmetatable({}, BaseState)
AttackState.__index = AttackState

local COMBO_MAX = 4
local HIT_TIME = 0.55
local COMBO_TIMEOUT = 1.2

function AttackState.new()
	return setmetatable(BaseState.new("Attack"), AttackState)
end

function AttackState:Enter(context)
	context.comboQueued = false
	context.hitEndTime = tick() + HIT_TIME
	context.lastInputTime = tick()

	context.AnimationController:PlaySlash(context.comboIndex)
end

function AttackState:HandleInput(input, context)
	if input == "M1" then
		context.comboQueued = true
		context.lastInputTime = tick()
	end
end

function AttackState:Update(_, context)
	-- chưa hết hit → chờ
	if tick() < context.hitEndTime then return end

	-- có buffer input → sang hit tiếp
	if context.comboQueued and context.comboIndex < COMBO_MAX then
		context.comboQueued = false
		context.comboIndex += 1
		context.hitEndTime = tick() + HIT_TIME
		context.AnimationController:PlaySlash(context.comboIndex)
		return
	end

	-- chờ combo window
	if tick() - context.lastInputTime < COMBO_TIMEOUT then
		return
	end

	-- combo kết thúc thật sự
	context.comboIndex = 1
	context.StateMachine:ChangeState(context.States.Idle)
end

return AttackState
