-- CombatHitHandler.client.lua
-- Fires Attack remote when animation Hit marker is reached
-- Supports proper Sekiro-style combo chaining
-- Client NEVER applies damage

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- =========================
-- REMOTES
-- =========================
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = Shared:WaitForChild("Remotes")
local CombatRemotes = Remotes:WaitForChild("Combat")
local AttackRemote = CombatRemotes:WaitForChild("Attack")

-- =========================
-- PLAYER
-- =========================
local Player = Players.LocalPlayer

-- =========================
-- TARGET RESOLVER
-- =========================
local PlayerScripts = Player:WaitForChild("PlayerScripts")
local ClientModules = PlayerScripts:WaitForChild("Client")
local CombatTargetResolver = require(ClientModules:WaitForChild("CombatTargetResolver"))

-- =========================
-- WAIT FOR AnimationController
-- =========================
local animationController
while not animationController do
	animationController = _G.__AnimationController
	task.wait(0.05)
end

print("[CombatHitHandler] Connected to AnimationController")

-- =========================
-- CONFIG
-- =========================
local DEFAULT_WEAPON = {
	Name = "Katana",
	Range = 8,
}

-- =========================
-- COMBO CONFIG (SEKIRO STYLE)
-- =========================
local comboIndex = 0
local lastComboTime = 0
local comboActive = false

-- Thời gian cho phép nối combo (KHÔNG phụ thuộc Idle)
-- Phải lớn hơn toàn bộ chuỗi animation combo
local COMBO_RESET_TIME = 5.0


-- =========================
-- HELPERS
-- =========================
local function isValidTarget(model)
	if typeof(model) ~= "Instance" then return false end
	if not model:IsA("Model") then return false end
	if not model.PrimaryPart then return false end
	if not model:FindFirstChild("Humanoid") then return false end
	if model.Humanoid.Health <= 0 then return false end
	return true
end

-- =========================
-- COMBO RESET CHECK (TIME-BASED)
-- =========================
local function updateComboWindow()
	if comboActive then
		local now = os.clock()
		if now - lastComboTime > COMBO_RESET_TIME then
			comboIndex = 0
			comboActive = false
		end
	end
end

-- =========================
-- HIT LOGIC
-- =========================
local function onAnimationPlayed(slotName, track)
	if not slotName then return end
	if not string.find(slotName, "Attack")
		and not string.find(slotName, "Slash") then
		return
	end
	if not track then return end

	local fired = false

	local function triggerHit()
		if fired then return end
		fired = true

		updateComboWindow()

		comboIndex += 1
		comboActive = true
		lastComboTime = os.clock()

		local character = Player.Character
		if not character then return end

		local target = CombatTargetResolver.GetTarget(character, DEFAULT_WEAPON.Range)
		if not isValidTarget(target) then return end

		local entityId = target:GetAttribute("EntityId")
		if not entityId then return end

		AttackRemote:FireServer({
			targetEntityId = entityId,
			weapon = DEFAULT_WEAPON,
			comboIndex = comboIndex,
		})

		print(
			"[CombatHitHandler] Attack intent sent",
			"EntityId =", entityId,
			"Combo =", comboIndex
		)
	end

	local markerConn
	markerConn = track:GetMarkerReachedSignal("Hit"):Connect(triggerHit)

	track.Stopped:Connect(function()
		if markerConn then
			markerConn:Disconnect()
		end
	end)
end

-- =========================
-- ANIMATION EVENT BIND
-- =========================
animationController.animationPlayedSignal.Event:Connect(onAnimationPlayed)
