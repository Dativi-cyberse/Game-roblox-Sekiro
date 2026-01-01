-- BaseState.lua
-- Base class for all FSM states

local BaseState = {}
BaseState.__index = BaseState

function BaseState.new(name)
	assert(name, "State must have a name")

	local self = setmetatable({}, BaseState)
	self.name = name
	self.allowedTransitions = {}
	return self
end

function BaseState:Enter(prevState, context) end
function BaseState:Exit(nextState, context) end
function BaseState:Update(dt, context) end
function BaseState:HandleInput(input, context) end

return BaseState
