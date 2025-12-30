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
	-- chỉ reset buffer, KHÔNG reset comboIndex ở đây
	context.comboQueued = false
	context.hitEndTime = tick() + HIT_TIME

	-- clamp combo index
	local combo = math.clamp(context.comboIndex or 1, 1, COMBO_MAX)

	-- play slash tương ứng
	context.AnimationController:PlaySlash(combo)
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
	-- chờ hết hit window
	if tick() < context.hitEndTime then
		return
	end

	-- nếu có buffer input → nối combo
	if context.comboQueued then
		context.comboQueued = false

		if context.comboIndex < COMBO_MAX then
			context.comboIndex += 1
		else
			-- vòng lại slash1 nếu muốn (Sekiro-style)
			context.comboIndex = 1
		end

		context.hitEndTime = tick() + HIT_TIME

		context.AnimationController:PlaySlash(context.comboIndex)
		return
	end

	-- không buffer nữa → thoát Attack
	context.comboIndex = 1
	context.StateMachine:ChangeState(context.States.Idle)
end

-- =====================
-- EXIT
-- =====================
function AttackState:Exit(context)
	context.comboQueued = false
end

return AttackState
