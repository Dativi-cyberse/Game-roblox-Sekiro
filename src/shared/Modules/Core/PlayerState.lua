local Constants = require(script.Parent.Constants or script.Parent.Constants)

local PlayerState = {}

PlayerState.States = {
	Idle = "Idle",
	Attacking = "Attacking",
	Guarding = "Guarding",
	Parrying = "Parrying",
	Staggered = "Staggered",
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

	-- timestamps
	self.lastAttackTime = 0
	self.guardStartTime = 0
	self.parryIntentTime = 0 -- when player signaled parry intent
	self.staggerUntil = 0

	-- simple cooldowns
	self.parryCooldownUntil = 0

	-- metadata
	self.owner = opts.owner -- optional (player/userId)

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
	-- disallow illegal transitions
	if self.state == PlayerState.States.Staggered and st ~= PlayerState.States.Idle then
		return false
	end
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

function PlayerState:StartGuard()
	if self.stamina < Constants.MIN_STAMINA_TO_GUARD then return false end
	self.guardStartTime = now()
	self:transitionTo(PlayerState.States.Guarding)
	return true
end

function PlayerState:EndGuard()
	if self.state == PlayerState.States.Guarding then
		self:transitionTo(PlayerState.States.Idle)
	end
	self.guardStartTime = 0
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
	-- posture is like a durability: if it reaches 0, player staggers
	self.posture = math.clamp(self.posture - amount, 0, Constants.POSTURE_MAX)
	if self.posture <= 0 then
		-- stagger
		self:SetStagger(1.0) -- default stagger 1s; callers may override
	end
end

function PlayerState:SetStagger(duration)
	self.staggerUntil = now() + (duration or 1)
	self:transitionTo(PlayerState.States.Staggered)
end

function PlayerState:IsStaggered()
	return now() < (self.staggerUntil or 0)
end

return PlayerState
