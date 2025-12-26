-- AttackState.lua
-- Attack state: Character is performing an attack

local BaseState = require(script.Parent.BaseState)

local AttackState = setmetatable({}, BaseState)
AttackState.__index = AttackState

function AttackState.new()
	local self = setmetatable(BaseState.new("Attack"), AttackState)
	self.allowedTransitions = {
		["Idle"] = true,
		["Move"] = true,
		["HitStun"] = true,
		["Death"] = true,
		-- Dash can cancel attack if allowed
		["Dash"] = true,
	}
	return self
end

function AttackState:Enter(prevState, context)
	-- Set timeout ONCE
	self.timeout = tick() + 1.0 -- Assume 1 second attack duration

	-- Start attack animation and logic
	if context.AnimationController then
		context.AnimationController:PlayAttack()
	end
	if context.Controllers and context.Controllers.CombatController then
		context.Controllers.CombatController:StartAttack()
	end
end

function AttackState:Exit(nextState, context)
	-- Stop attack if interrupted
	if context.Controllers and context.Controllers.CombatController then
		context.Controllers.CombatController:StopAttack()
	end
	-- Clear state-local timer
	self.timeout = nil
end

function AttackState:Update(dt, context)
	-- Check timeout
	if tick() >= self.timeout then
		-- Reset comboQueued BEFORE re-entering Attack
		context.comboQueued = false
		-- Transition to Idle or Move
		if context.comboQueued then
			-- If combo queued, stay in Attack (but since we reset it, it won't)
			return
		else
			-- Transition to Idle
			local stateMachine = context.StateMachine or context.fsm -- Assuming context has reference
			if stateMachine then
				stateMachine:ChangeState("Idle")
			end
		end
	end
end

return AttackState
