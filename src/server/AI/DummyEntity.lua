-- DummyEntity.lua
-- A simple data container for the Dummy Enemy that is compatible with CombatService.
-- It mimics the structure of a PlayerState without the complexity.

local DummyEntity = {}
DummyEntity.__index = DummyEntity

function DummyEntity.new(model)
	local self = setmetatable({}, DummyEntity)

	-- Visuals
	self.Model = model
	self.Humanoid = model:FindFirstChild("Humanoid")
	self.RootPart = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model.PrimaryPart

	-- Combat Stats (CombatService compatible)
	self.Health = 100
	self.MaxHealth = 100
	self.Posture = 100
	self.MaxPosture = 100
	self.Guard = 100
	self.MaxGuard = 100
	
	-- State & Flags
	self.State = "Idle" -- "Idle", "Guarding", "Attacking", "Staggered", "Dead"
	self._isGuarding = false
	self._isGuardBroken = false
	self._isDead = false
	
	-- Timestamps (os.clock based)
	self.parryIntentTime = 0
	self._lastAttackTime = 0
	self._staggerUntil = 0
	
	return self
end

-- Sync internal data with Roblox Humanoid for display
function DummyEntity:UpdateVisuals()
	if self.Humanoid then
		self.Humanoid.Health = math.clamp(self.Health, 0, self.Humanoid.MaxHealth)
	end

	-- Sync posture-broken state for client-side deathblow detection
	local isBroken = (self.Posture <= 0)
	if self.Model and self.Model:GetAttribute("PostureBroken") ~= isBroken then
		self.Model:SetAttribute("PostureBroken", isBroken)
	end
end

-- Reset state after death or spawn
function DummyEntity:Reset()
	self.Health = self.MaxHealth
	self.Posture = self.MaxPosture
	self.Guard = self.MaxGuard
	self._staggerUntil = 0
	self._isGuardBroken = false
	self._isDead = false
	self.State = "Idle"
end

-- HOTFIX: Update method for posture regeneration and flag clearing
function DummyEntity:Update(dt)
	-- HOTFIX: Posture regeneration over time
	local now = os.clock()
	-- HOTFIX: Pause during stagger
	if self._staggerUntil > now then
		return
	end
	-- HOTFIX: Pause when attacking
	if self.State == "Attacking" then
		return
	end
	-- HOTFIX: Slow deterministic posture regen
	self.Posture = math.min(self.MaxPosture, self.Posture + dt * 5)
	-- HOTFIX: Clear guard flag safely
	if self._isGuarding and self.State ~= "Guarding" then
		self._isGuarding = false
	end
	-- HOTFIX: Clear parry intent if expired
	if self.parryIntentTime > 0 and now - self.parryIntentTime > 0.5 then
		self.parryIntentTime = 0
	end
	-- HOTFIX: Update visuals
	self:UpdateVisuals()
end

return DummyEntity
