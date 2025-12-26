-- BaseState.lua
-- Base class for all FSM states
-- Provides common interface and transition validation

local BaseState = {}
BaseState.__index = BaseState

-- @param name string - The name of the state (e.g., "Idle")
function BaseState.new(name)
	local self = setmetatable({}, BaseState)
	self.name = name
	-- allowedTransitions: table of state names this state can transition to
	self.allowedTransitions = {}
	return self
end

-- Called when entering this state
-- @param prevState BaseState - The previous state (nil if initial)
-- @param context table - Shared context (Humanoid, Animator, Controllers, etc.)
function BaseState:Enter(prevState, context)
	-- Override in subclasses
end

-- Called when exiting this state
-- @param nextState BaseState - The next state
-- @param context table - Shared context
function BaseState:Exit(nextState, context)
	-- Override in subclasses
end

-- Called every frame while in this state
-- @param dt number - Delta time
-- @param context table - Shared context
function BaseState:Update(dt, context)
	-- Override in subclasses if needed
end

return BaseState
