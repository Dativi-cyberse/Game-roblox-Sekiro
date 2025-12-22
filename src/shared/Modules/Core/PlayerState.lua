local PlayerState = {}
PlayerState.__index = PlayerState

function PlayerState.new()
    return setmetatable({
        HP = 100,
        Shield = 50,
        Stamina = 100,
        IsStunned = false,
        StunEndTime = 0,
        IsAttacking = false,
        IsSprinting = false,
        ParryWindow = false,
        CriticalWindow = false,
        CriticalEndTime = 0,
    }, PlayerState)
end

function PlayerState:IsDead()
    return self.HP <= 0
end

function PlayerState:Tick(dt)
    if self.IsStunned and tick() > self.StunEndTime then
        self.IsStunned = false
    end
    if self.CriticalWindow and tick() > self.CriticalEndTime then
        self.CriticalWindow = false
    end
end

function PlayerState:DrainStamina(amount)
    self.Stamina = math.max(0, self.Stamina - amount)
end

function PlayerState:TakeHP(amount)
    self.HP = math.max(0, self.HP - amount)
end

function PlayerState:ApplyStun(duration)
    self.IsStunned = true
    self.StunEndTime = tick() + duration
end

function PlayerState:SetAttacking(state)
    self.IsAttacking = state
end

function PlayerState:SetSprinting(state)
    self.IsSprinting = state
end

function PlayerState:OpenParryWindow()
    self.ParryWindow = true
end

function PlayerState:EnableCriticalWindow(duration)
    self.CriticalWindow = true
    self.CriticalEndTime = tick() + duration
end

return PlayerState
