-- DummyFSM.lua
-- Time-based Finite State Machine for the Dummy.
-- Enforces state duration and transitions.
-- NOTE: This is a legacy/fallback FSM. 
-- The active NPC system uses the Shared StateMachine via DummyEnemy.lua.

local DummyFSM = {}
DummyFSM.__index = DummyFSM

local STATES = {
	Idle = "Idle",
	Guard = "Guard",
	Attack = "Attack",
	Stagger = "Stagger",
	Death = "Death"
}

function DummyFSM.new(entity)
	local self = setmetatable({}, DummyFSM)
	self.entity = entity
	self.currentState = STATES.Idle
	self.stateTimer = 0
	self.stateDuration = 0
	return self
end

function DummyFSM:GetCurrentState()
	return self.currentState
end

-- Safe transition method
function DummyFSM:SetState(newState, duration)
	-- Prevent self-transition (unless it's a combo chain, but we keep it simple)
	if self.currentState == newState and newState ~= STATES.Attack then
		return
	end

	self.currentState = newState
	self.stateTimer = 0
	self.stateDuration = duration or 0
	
	-- Sync to Entity for CombatService visibility
	if newState == STATES.Guard then
		self.entity.State = "Guarding"
		self.entity._isGuarding = true
	elseif newState == STATES.Attack then
		self.entity.State = "Attacking"
		self.entity._isGuarding = false
	elseif newState == STATES.Stagger then
		self.entity.State = "Staggered"
		self.entity._isGuarding = false
	elseif newState == STATES.Death then
		self.entity.State = "Dead"
		self.entity._isGuarding = false
	else
		self.entity.State = "Idle"
		self.entity._isGuarding = false
	end
end

function DummyFSM:Update(dt)
	print("[DummyFSM]", self.currentState, "Intent:", self.entity.Intent)

	local now = os.clock()
	self.stateTimer += dt

	-- PRIORITY 1: Death
	if self.entity.Health <= 0 and self.currentState ~= STATES.Death then
		self:SetState(STATES.Death, 9999)
		return
	end

	if self.currentState == STATES.Death then
		return
	end

	-- PRIORITY 2: Stagger
	if self.entity._staggerUntil > now then
		if self.currentState ~= STATES.Stagger then
			self:SetState(STATES.Stagger, self.entity._staggerUntil - now)
		end
		return
	elseif self.currentState == STATES.Stagger then
		self:SetState(STATES.Idle, 0)
	end

	-- PRIORITY 3: State duration end
	if self.stateDuration > 0 and self.stateTimer >= self.stateDuration then
		self:SetState(STATES.Idle, 0)
	end

	-- PRIORITY 4: Intent processing
	if self.currentState == STATES.Idle or self.currentState == STATES.Guard then
		local intent = self.entity.Intent

		if intent == "Attack" then
			self:SetState(STATES.Attack, 0.5)

		elseif intent == "Guard" then
			if self.currentState ~= STATES.Guard then
				self:SetState(STATES.Guard, 1.0)
			end

		elseif intent == "Parry" then
			self.entity.parryIntentTime = now
			self:SetState(STATES.Guard, 0.3)
		end

		-- CLEAR intent after processing
		self.entity.Intent = nil
	end

	-- PRIORITY 5: Parry window reset (MUST be global)
	if self.entity.parryIntentTime > 0 and now - self.entity.parryIntentTime > 0.25 then
		self.entity.parryIntentTime = 0
	end
end
return DummyFSM
