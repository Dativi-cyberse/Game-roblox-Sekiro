-- StateMachine.lua (object-based FSM)

local RunService = game:GetService("RunService")

local StateMachine = {}
StateMachine.__index = StateMachine

function StateMachine.new(initialState, context)
	assert(type(initialState) == "table", "[FSM] initialState must be state object")

	local self = setmetatable({}, StateMachine)
	self.currentState = nil
	self.context = context

	-- 🔥 UPDATE LOOP
	self._conn = RunService.Heartbeat:Connect(function(dt)
		if self.currentState and self.currentState.Update then
			self.currentState:Update(dt, self.context)
		end
	end)

	self:ChangeState(initialState)
	return self
end

function StateMachine:GetState()
	return self.currentState
end

function StateMachine:ChangeState(state)
	if type(state) ~= "table" then
		warn("[FSM] ChangeState expects STATE OBJECT, got", typeof(state))
		return
	end

	if self.currentState == state then
		return
	end

	local prevName = self.currentState and self.currentState.name or "None"
	local nextName = state.name or "Unknown"

	if self.currentState and self.currentState.Exit then
		self.currentState:Exit(self.context)
	end

	self.currentState = state

	if state.Enter then
		state:Enter(self.context)
	end

	print("[FSM]", prevName, "->", nextName)
end

function StateMachine:Destroy()
	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
end

return StateMachine
