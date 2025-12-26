-- StateMachine.lua
-- Manages state transitions and calls state methods
-- Validates transitions and logs changes

local StateMachine = {}
StateMachine.__index = StateMachine

-- @param initialState BaseState - The starting state
-- @param context table - Shared context table (Humanoid, Animator, Controllers, etc.)
function StateMachine.new(initialState, context)
	local self = setmetatable({}, StateMachine)
	self.currentState = initialState
	self.context = context or {}
	self.states = {} -- Map of state names to state objects
	return self
end

-- Registers a state object
-- @param state BaseState
function StateMachine:RegisterState(state)
	self.states[state.name] = state
end

-- Attempts to change to a new state
-- @param newStateName string - Name of the target state
-- @param contextData table - Optional additional data for Enter/Exit
-- @return boolean - True if transition succeeded
function StateMachine:ChangeState(newStateName, contextData)
	local newState = self.states[newStateName]
	if not newState then
		warn(string.format("[FSM] Unknown state: %s", newStateName))
		return false
	end

	if self.currentState.name == newStateName then
		return true -- Already in state
	end

	-- Check if transition is allowed
	if not self.currentState.allowedTransitions[newStateName] then
		warn(string.format("[FSM] Invalid transition: %s -> %s", self.currentState.name, newStateName))
		return false
	end

	-- Exit current state
	self.currentState:Exit(newState, self.context)

	-- Log transition
	print(string.format("[FSM] %s -> %s", self.currentState.name, newStateName))

	-- Enter new state
	local prevState = self.currentState
	self.currentState = newState
	self.currentState:Enter(prevState, self.context)

	return true
end

-- Gets the current state object
-- @return BaseState
function StateMachine:GetState()
	return self.currentState
end

-- Updates the current state
-- @param dt number - Delta time
function StateMachine:Update(dt)
	if self.currentState and self.currentState.Update then
		self.currentState:Update(dt, self.context)
	end
end

return StateMachine
