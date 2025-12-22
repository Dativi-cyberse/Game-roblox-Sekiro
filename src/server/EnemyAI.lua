-- EnemyAI.lua
-- Simple AI for Sekiro-style posture combat. No animations or pathfinding.

local EnemyAI = {}
EnemyAI.__index = EnemyAI

local DEFAULTS = {
    Type = "Normal", -- or "Boss"
    AggroRange = 20,

    -- timings
    AttackCooldown = 1.2,
    HeavyAttackChance = 0.2,
    DelayedAttackChance = 0.15,

    -- guard thresholds
    LowGuardThreshold = 0.3, -- fraction of MaxGuard considered "low"
}

-- State machine states
local STATES = {
    Idle = "Idle",
    Attacking = "Attacking",
    Recovering = "Recovering",
    Stunned = "Stunned",
}

-- Constructor
function EnemyAI.new(opts)
    opts = opts or {}
    local self = setmetatable({}, EnemyAI)
    self.Type = opts.Type or DEFAULTS.Type
    self.MaxGuard = opts.MaxGuard or 100
    self.Guard = opts.Guard or self.MaxGuard
    self.Health = opts.Health or (opts.MaxHealth or 200)

    self.state = STATES.Idle
    self._stateTimer = 0
    self._attackCooldown = 0

    -- Boss specific: apply guard reduction cap
    self.isBoss = (self.Type == "Boss")

    return self
end

local function clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

-- React to parry: become staggered (stunned)
function EnemyAI:OnParried(duration)
    duration = duration or 0.3
    self.state = STATES.Stunned
    self._stateTimer = math.max(self._stateTimer, duration)
end

-- React to guard break
function EnemyAI:OnGuardBreak()
    -- heavy stagger and enter recovering
    self.state = STATES.Recovering
    self._stateTimer = 1.0
    -- reset guard to small value
    self.Guard = math.floor(self.MaxGuard * 0.2)
end

-- Called when engaged in a clash: reduce guard but cap for boss
function EnemyAI:ApplyClashGuardLoss(amount)
    if self.isBoss then
        local cap = math.floor(self.MaxGuard * 0.2)
        amount = math.min(amount, cap)
    end
    self.Guard = clamp(self.Guard - amount, 0, self.MaxGuard)
    if self.Guard <= 0 then
        self:OnGuardBreak()
    end
end

-- Low guard checks
function EnemyAI:IsLowGuard()
    return (self.Guard / math.max(1, self.MaxGuard)) <= DEFAULTS.LowGuardThreshold
end

-- ChooseNextAction based on player state
-- playerState: an instance of PlayerState or similar table
function EnemyAI:ChooseNextAction(playerState)
    -- Simple heuristics
    if not playerState then
        return { action = "Wait" }
    end

    if self.state == STATES.Stunned or self.state == STATES.Recovering then
        return { action = "Recover" }
    end

    -- If player guard is very low, prefer heavy attack to break HP
    if playerState.Guard and playerState.Guard <= math.max(1, playerState.MaxGuard * 0.25) then
        return { action = "HeavyAttack" }
    end

    -- Boss: more aggressive choices
    if self.isBoss then
        local r = math.random()
        if r < DEFAULTS.DelayedAttackChance then
            return { action = "DelayedAttack" }
        elseif r < DEFAULTS.DelayedAttackChance + DEFAULTS.HeavyAttackChance then
            return { action = "HeavyAttack" }
        else
            return { action = "LightAttack" }
        end
    end

    -- Normal enemy: mostly light attacks
    local r = math.random()
    if r < 0.15 then
        return { action = "HeavyAttack" }
    else
        return { action = "LightAttack" }
    end
end

-- Update: advance timers and state. deltaTime in seconds.
function EnemyAI:Update(dt)
    dt = dt or 0
    if self._attackCooldown > 0 then
        self._attackCooldown = math.max(0, self._attackCooldown - dt)
    end

    if self._stateTimer > 0 then
        self._stateTimer = math.max(0, self._stateTimer - dt)
        if self._stateTimer <= 0 then
            -- transition out of stunned/recovering
            if self.state == STATES.Stunned or self.state == STATES.Recovering then
                self.state = STATES.Idle
            end
        end
    end
end

return EnemyAI
