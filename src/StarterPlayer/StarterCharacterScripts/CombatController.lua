-- CombatController.lua
-- FSM Adapter / Bridge
-- Purpose: keep legacy references alive, forward actions to FSM
-- NO combat logic, NO state, NO animation ownership

local CombatController = {}
CombatController.__index = CombatController

function CombatController.new(stateMachine, context)
	assert(stateMachine, "[CombatController] StateMachine is required")
	assert(context, "[CombatController] Context is required")

	local self = setmetatable({}, CombatController)
	self.fsm = stateMachine
	self.context = context
	return self
end

-- =========================
-- ATTACK (M1)
-- =========================
function CombatController:HandleM1()
	-- If already in Attack, queue combo
	if self.fsm:GetState().name == "Attack" then
		self.context.comboQueued = true
		return
	end
	-- Forward to FSM
	self.fsm:ChangeState("Attack")
end

-- =========================
-- GUARD / BLOCK
-- =========================
function CombatController:SetGuarding(state)
	if state then
		self.fsm:ChangeState("Block")
	else
		self.fsm:ChangeState("Idle")
	end
end

-- =========================
-- DASH
-- =========================
function CombatController:Dash()
	self.fsm:ChangeState("Dash")
end

-- =========================
-- SPRINT (optional mapping)
-- =========================
function CombatController:SetSprinting(state)
	if state then
		self.fsm:ChangeState("Move")
	else
		self.fsm:ChangeState("Idle")
	end
end

-- =========================
-- WEAPON EQUIP (NO LOGIC)
-- =========================
function CombatController:SetWeaponEquipped(equipped)
	-- FSM or higher-level system decides what to do
	-- kept only for compatibility
end

-- =========================
-- CLEANUP
-- =========================
function CombatController:Cleanup()
	-- nothing to clean
end

return CombatController
