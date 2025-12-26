local Constants = require(script.Parent.Constants or script.Parent.Constants)

local PlayerState = {}

PlayerState.States = {
	Idle = "Idle",
	Attacking = "Attacking",
	Blocking = "Blocking",
	Parrying = "Parrying",
	Staggered = "Staggered",          -- Posture broken, cannot act
	Deathblow = "Deathblow",          -- Executing deathblow (locked)
	DeathblowVictim = "DeathblowVictim", -- Being deathblown (locked)
}

local function now()
	return tick()
end

-- Create a new state object for a player (server-side)
function PlayerState.new(opts)
	opts = opts or {}
	local self = {}
	self.state = PlayerState.States.Idle
	self.stateStarted = now()

	-- resources
	self.stamina = opts.stamina or 100
	self.posture = opts.posture or Constants.POSTURE_MAX
	self.maxPosture = opts.maxPosture or Constants.POSTURE_MAX
	self.health = opts.health or 100
	self.maxHealth = opts.maxHealth or 100

	-- timestamps
	self.lastAttackTime = 0
	self.blockStartTime = 0
	self.parryIntentTime = 0 -- when player signaled parry intent
	self.staggerUntil = 0
	self._lastCombatActionTime = 0

	-- simple cooldowns
	self.parryCooldownUntil = 0
	self.attackCooldownUntil = 0

	-- metadata
	self.owner = opts.owner -- optional (player/userId)
	self.isBlocking = false

	setmetatable(self, {__index = PlayerState})
	return self
end

function PlayerState:Get()
	return self.state
end

function PlayerState:Is(st)
	return self.state == st
end

function PlayerState:transitionTo(st)
	if self.state == st then return true end
	
	-- State transition rules for Sekiro-style combat
	-- Staggered characters can only return to Idle
	if self.state == PlayerState.States.Staggered and st ~= PlayerState.States.Idle then
		return false
	end
	
	-- Locked states cannot transition except to Idle
	if (self.state == PlayerState.States.Deathblow or 
	    self.state == PlayerState.States.DeathblowVictim) and st ~= PlayerState.States.Idle then
		return false
	end
	
	-- Cannot attack while parrying (parry is defensive action)
	if self.state == PlayerState.States.Attacking and st == PlayerState.States.Parrying then
		return false
	end
	
	self.state = st
	self.stateStarted = now()
	return true
end

function PlayerState:CanAttack()
	if self.state == PlayerState.States.Staggered then return false end
	if self.stamina <= 0 then return false end
	return true
end

function PlayerState:StartAttack()
	if not self:CanAttack() then return false end
	self.lastAttackTime = now()
	self:transitionTo(PlayerState.States.Attacking)
	return true
end

function PlayerState:StartBlock()
	if self.state == PlayerState.States.Staggered or
	   self.state == PlayerState.States.Deathblow or
	   self.state == PlayerState.States.DeathblowVictim then
		return false
	end
	self.blockStartTime = now()
	self.isBlocking = true
	self:transitionTo(PlayerState.States.Blocking)
	return true
end

function PlayerState:EndBlock()
	if self.state == PlayerState.States.Blocking then
		self:transitionTo(PlayerState.States.Idle)
	end
	self.blockStartTime = 0
	self.isBlocking = false
end

-- Legacy alias for compatibility
function PlayerState:StartGuard()
	return self:StartBlock()
end

function PlayerState:EndGuard()
	return self:EndBlock()
end

function PlayerState:RecordParryIntent()
	self.parryIntentTime = now()
	-- parry intent does not immediately change state; CheckParry will be used when attack arrives
end

function PlayerState:CheckParry(attackTime)
	-- server-side check: compare recorded parry intent with attack time
	if attackTime == nil then return false end
	local window = Constants.PARRY_WINDOW + Constants.PARRY_GRACE
	local dt = math.abs(self.parryIntentTime - attackTime)
	if dt <= window and now() <= self.parryCooldownUntil then
		-- if parry on cooldown, fail
		return false
	end
	if dt <= window then
		return true
	end
	return false
end

function PlayerState:AddStamina(amount)
	self.stamina = math.max(0, self.stamina + amount)
end

function PlayerState:ConsumeStamina(amount)
	local take = math.min(self.stamina, amount)
	self.stamina = self.stamina - take
	return take
end

function PlayerState:AddPosture(amount)
	-- Posture increases as it takes damage (bar fills up)
	-- When posture >= max, character is broken
	self.posture = math.clamp((self.posture or 0) + amount, 0, self.maxPosture or Constants.POSTURE_MAX)
	self._lastCombatActionTime = now()
	
	if self.posture >= (self.maxPosture or Constants.POSTURE_MAX) then
		-- Posture broken - enter stagger state
		self:SetStagger(1.5)
	end
end

function PlayerState:SetPosture(value)
	self.posture = math.clamp(value, 0, self.maxPosture or Constants.POSTURE_MAX)
	self._lastCombatActionTime = now()
end

function PlayerState:SetStagger(duration)
	self.staggerUntil = now() + (duration or 1)
	self:transitionTo(PlayerState.States.Staggered)
end

function PlayerState:IsStaggered()
	return now() < (self.staggerUntil or 0)
end

--- Checks if character can perform deathblow
function PlayerState:CanDeathblow()
	return self.state == PlayerState.States.Idle or 
	       self.state == PlayerState.States.Attacking
end

--- Enters deathblow state (locks character)
function PlayerState:StartDeathblow()
	if not self:CanDeathblow() then
		return false
	end
	self:transitionTo(PlayerState.States.Deathblow)
	return true
end

--- Enters deathblow victim state (locked, cannot act)
function PlayerState:StartDeathblowVictim()
	self:transitionTo(PlayerState.States.DeathblowVictim)
end

--- Checks if character is locked (cannot act)
function PlayerState:IsLocked()
	return self.state == PlayerState.States.Deathblow or
	       self.state == PlayerState.States.DeathblowVictim or
	       self.state == PlayerState.States.Staggered
end

return PlayerState
