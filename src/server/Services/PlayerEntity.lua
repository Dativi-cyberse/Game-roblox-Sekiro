-- PlayerEntity.lua
-- Server-side wrapper for Player character to make it compatible with CombatService.
-- Mimics the structure of DummyEntity.

local PlayerEntity = {}
PlayerEntity.__index = PlayerEntity

function PlayerEntity.new(player, character)
    local self = setmetatable({}, PlayerEntity)

    self.Player = player
    self.Character = character
    self.Model = character -- [FIX] Ensure CombatService can generate unique ID
    self.Humanoid = character:FindFirstChild("Humanoid")
    self.RootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character.PrimaryPart

    -- Combat Stats (Synced with Humanoid where applicable)
    self.Health = self.Humanoid and self.Humanoid.Health or 100
    self.MaxHealth = self.Humanoid and self.Humanoid.MaxHealth or 100
    
    -- Sekiro Stats (Server Authoritative)
    self.Posture = 100
    self.MaxPosture = 100
    self.Guard = 100 -- Used interchangeably with Shield/Guard in CombatService
    self.MaxGuard = 100

    -- State Flags
    self.EntityType = "PLAYER" -- [FIX] Enable correct damage scaling in CombatService
    self.State = "Idle" -- "Idle", "Guarding", "Staggered", "Dead"
    self._isGuarding = false
    self._isParrying = false
    self._isGuardBroken = false
    self._isDead = false

    -- Timestamps (os.clock based)
    self.parryIntentTime = 0
    self._lastAttackTime = 0
    self._staggerUntil = 0
    self._brokenUntil = 0 -- Window for deathblows

    return self
end

function PlayerEntity:Update(dt)
    if not self.Humanoid or not self.Humanoid.Parent then 
        self._isDead = true
        return 
    end

    -- 1. Sync Health: Entity <-> Humanoid
    -- If Humanoid took external damage (e.g. void, kill brick), sync to Entity
    if self.Humanoid.Health < self.Health then
        self.Health = self.Humanoid.Health
    -- If Entity took combat damage (via CombatService), sync to Humanoid
    elseif self.Health < self.Humanoid.Health then
        self.Humanoid.Health = self.Health
    end

    -- Check Death
    if self.Health <= 0 then
        self._isDead = true
        self.State = "Dead"
        return
    end

    -- 2. Posture Regeneration
    local now = os.clock()
    local REGEN_RATE = 15 -- Posture per second
    local REGEN_DELAY = 2.0 -- Seconds to wait after last combat action

    local lastAction = math.max(self._lastAttackTime, self._staggerUntil)
    
    -- Only regen if not staggered and time has passed
    if now - lastAction > REGEN_DELAY and self.Posture < self.MaxPosture then
        self.Posture = math.min(self.MaxPosture, self.Posture + (REGEN_RATE * dt))
    end

    -- 3. Clear Stagger
    if self._staggerUntil > 0 and now > self._staggerUntil then
        self._staggerUntil = 0
        self._isGuardBroken = false
        if self.State == "Staggered" then
            self.State = "Idle"
        end
    end

    -- 4. Auto-expire Guard/Parry State (Server Authoritative Timeout)
    -- Fixes invincibility bug where player gets stuck in Guarding state
    if self._isGuarding or self._isParrying then
        local elapsed = now - (self.parryIntentTime or 0)
        if elapsed > 0.75 then -- Max guard window
            self._isGuarding = false
            self._isParrying = false
            if self.State == "Guarding" then
                self.State = "Idle"
            end
        end
    end
end

return PlayerEntity
