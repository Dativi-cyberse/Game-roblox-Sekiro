local BaseState = require(script.Parent.BaseState)

local AttackState = setmetatable({}, BaseState)
AttackState.__index = AttackState

local COMBO_MAX = 4
local HIT_TIME = 0.55

function AttackState.new()
	return setmetatable(BaseState.new("Attack"), AttackState)
end

-- =====================
-- ENTER
-- =====================
function AttackState:Enter(context)
	context.comboQueued = false
	context.hitEndTime = tick() + HIT_TIME

	-- Play current slash
	context.AnimationController:PlaySlash(context.comboIndex)
end

-- =====================
-- INPUT
-- =====================
function AttackState:HandleInput(input, context)
	if input == "M1" then
		context.comboQueued = true
	end
end

-- =====================
-- UPDATE
-- =====================
function AttackState:Update(_, context)
	-- Chưa hết animation hit → chờ
	if tick() < context.hitEndTime then
		return
	end

	-- Có buffer input & còn combo → đánh hit tiếp
	if context.comboQueued and context.comboIndex < COMBO_MAX then
		context.comboQueued = false
		context.comboIndex += 1
		context.hitEndTime = tick() + HIT_TIME
		context.AnimationController:PlaySlash(context.comboIndex)
		return
	end

	-- 🔥 KẾT THÚC ATTACK → LUÔN VỀ IDLE
	context.comboIndex = 1
	context.StateMachine:ChangeState(context.States.Idle)
end

-- =====================
-- EXIT
-- =====================
function AttackState:Exit(context)
	-- đảm bảo reset buffer
	context.comboQueued = false
end

return AttackState
