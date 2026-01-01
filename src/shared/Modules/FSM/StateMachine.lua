-- StateMachine.lua
-- Core FSM – Mugen style, stable

local StateMachine = {}
StateMachine.__index = StateMachine

function StateMachine.new(initialState, context)
	assert(initialState, "StateMachine requires initialState")
	assert(context, "StateMachine requires context")

	local self = setmetatable({}, StateMachine)

	self.currentState = initialState
	self.context = context

	print("[FSM] Init ->", initialState.name)

	if initialState.Enter then
		initialState:Enter(nil, context)
	end

	return self
end

function StateMachine:GetState()
	return self.currentState
end

function StateMachine:ChangeState(nextState)
	if not nextState then return end
	if self.currentState == nextState then return end

	local prevState = self.currentState

	if prevState and prevState.allowedTransitions then
		if not prevState.allowedTransitions[nextState.name] then
			return
		end
	end

	if prevState and prevState.Exit then
		prevState:Exit(nextState, self.context)
	end

	self.currentState = nextState

	if nextState.Enter then
		nextState:Enter(prevState, self.context)
	end

	print("[FSM]", prevState and prevState.name or "None", "->", nextState.name)
end

function StateMachine:HandleInput(input)
	if self.currentState and self.currentState.HandleInput then
		self.currentState:HandleInput(input, self.context)
	end
end

function StateMachine:Update(dt)
	if self.currentState and self.currentState.Update then
		self.currentState:Update(dt, self.context)
	end
end

return StateMachine
