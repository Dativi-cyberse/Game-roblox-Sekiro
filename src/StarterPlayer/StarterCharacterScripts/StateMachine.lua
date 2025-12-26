-- StateMachine.lua
-- Pure state transition logic for character combat states
-- WHY: Centralized state management prevents illegal actions and ensures consistency

local StateMachine = {}
StateMachine.__index = StateMachine

-- Combat states
StateMachine.States = {
	Idle = "Idle",
	Attacking = "Attacking",
	Blocking = "Blocking",
	Parrying = "Parrying",
	Stunned = "Stunned",
	Dashing = "Dashing",
	Dead = "Dead",
}

-- State transition rules (fromState -> {allowedToStates})
-- WHY: Explicit rules prevent bugs and make state logic clear
local TRANSITION_RULES = {
	[StateMachine.States.Idle] = {
		[StateMachine.States.Attacking] = true,
		[StateMachine.States.Blocking] = true,
		[StateMachine.States.Parrying] = true,
		[StateMachine.States.Dashing] = true,
		[StateMachine.States.Dead] = true,
	},
	[StateMachine.States.Attacking] = {
		[StateMachine.States.Idle] = true,
		[StateMachine.States.Stunned] = true, -- Can be interrupted
		[StateMachine.States.Dead] = true,
	},
	[StateMachine.States.Blocking] = {
		[StateMachine.States.Idle] = true,
		[StateMachine.States.Parrying] = true, -- Can parry from block
		[StateMachine.States.Stunned] = true,
		[StateMachine.States.Dead] = true,
	},
	[StateMachine.States.Parrying] = {
		[StateMachine.States.Idle] = true,
		[StateMachine.States.Stunned] = true,
		[StateMachine.States.Dead] = true,
	},
	[StateMachine.States.Stunned] = {
		[StateMachine.States.Idle] = true, -- Recovery
		[StateMachine.States.Dead] = true,
	},
	[StateMachine.States.Dashing] = {
		[StateMachine.States.Idle] = true,
		[StateMachine.States.Attacking] = true, -- Can cancel into attack
		[StateMachine.States.Dead] = true,
	},
	[StateMachine.States.Dead] = {
		-- Dead state is terminal (only reset on respawn)
	},
}

function StateMachine.new()
	local self = setmetatable({}, StateMachine)
	self.currentState = StateMachine.States.Idle
	self.stateChangedSignal = Instance.new("BindableEvent")
	return self
end

--- Attempts to transition to a new state
-- @param newState string - Target state
-- @return boolean - True if transition succeeded
function StateMachine:TransitionTo(newState)
	if self.currentState == newState then
		return true -- Already in state
	end
	
	-- Check if transition is allowed
	local allowedStates = TRANSITION_RULES[self.currentState]
	if not allowedStates or not allowedStates[newState] then
		warn(string.format("[StateMachine] Illegal transition: %s -> %s", self.currentState, newState))
		return false
	end
	
	local oldState = self.currentState
	self.currentState = newState
	
	-- Fire state changed signal
	self.stateChangedSignal:Fire(oldState, newState)
	
	return true
end

--- Gets the current state
-- @return string
function StateMachine:GetState()
	return self.currentState
end

--- Checks if currently in a specific state
-- @param state string
-- @return boolean
function StateMachine:Is(state)
	return self.currentState == state
end

--- Checks if character can perform actions
-- @return boolean
function StateMachine:CanAct()
	return self.currentState ~= StateMachine.States.Dead and
	       self.currentState ~= StateMachine.States.Stunned
end

--- Checks if character can attack
-- @return boolean
function StateMachine:CanAttack()
	return self:CanAct() and (
		self.currentState == StateMachine.States.Idle or
		self.currentState == StateMachine.States.Dashing -- Can cancel dash into attack
	)
end

--- Checks if character can block
-- @return boolean
function StateMachine:CanBlock()
	return self:CanAct() and (
		self.currentState == StateMachine.States.Idle or
		self.currentState == StateMachine.States.Blocking
	)
end

--- Checks if character can parry
-- @return boolean
function StateMachine:CanParry()
	return self:CanAct() and (
		self.currentState == StateMachine.States.Idle or
		self.currentState == StateMachine.States.Blocking
	)
end

--- Checks if character can dash
-- @return boolean
function StateMachine:CanDash()
	return self:CanAct() and (
		self.currentState == StateMachine.States.Idle or
		self.currentState == StateMachine.States.Attacking -- Can cancel attack with dash
	)
end

--- Connects a callback to state changes
-- @param callback function(oldState, newState)
-- @return RBXScriptConnection
function StateMachine:OnStateChanged(callback)
	return self.stateChangedSignal.Event:Connect(callback)
end

--- Resets state machine to initial state
function StateMachine:Reset()
	self.currentState = StateMachine.States.Idle
end

return StateMachine

