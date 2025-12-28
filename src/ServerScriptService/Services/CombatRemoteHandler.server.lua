local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:FindFirstChild("Shared")
if not Shared then return end

local Remotes = Shared:FindFirstChild("Remotes")
if not Remotes then return end

local CombatRemotes = Remotes:FindFirstChild("Combat")
if not CombatRemotes then return end

local CombatService = require(script.Parent.CombatService)

-- =========================
-- CONFIG
-- =========================
local DEATHBLOW_RANGE = 6
local DEATHBLOW_ANGLE_DOT = 0.2 -- càng thấp càng dễ deathblow từ sau

local function toEntity(model)
	return { Model = model }
end

local function getRoot(model)
	return model and model:FindFirstChild("HumanoidRootPart")
end

local function canDeathblow(attackerModel, targetModel)
	if not attackerModel or not targetModel then
		return false
	end

	local aRoot = getRoot(attackerModel)
	local tRoot = getRoot(targetModel)
	if not aRoot or not tRoot then
		return false
	end

	-- Distance check
	local dist = (aRoot.Position - tRoot.Position).Magnitude
	if dist > DEATHBLOW_RANGE then
		return false
	end

	-- Angle check (sau lưng target)
	local toAttacker = (aRoot.Position - tRoot.Position).Unit
	local targetForward = tRoot.CFrame.LookVector
	local dot = targetForward:Dot(toAttacker)

	if dot > DEATHBLOW_ANGLE_DOT then
		return false
	end

	-- Posture check (CombatService PHẢI CUNG CẤP)
	if not CombatService.IsPostureBroken then
		return false
	end

	if not CombatService.IsPostureBroken(toEntity(targetModel)) then
		return false
	end

	return true
end

-- =========================
-- M1 ATTACK / DEATHBLOW
-- =========================
local M1Remote = CombatRemotes:FindFirstChild("M1Event")
if M1Remote then
	M1Remote.OnServerEvent:Connect(function(player, attackData)
		if not player or not player:IsA("Player") then return end
		local character = player.Character
		if not character then return end

		attackData = attackData or {}
		local targetModel = attackData.target

		local attackerEntity = toEntity(character)
		local targetEntity = targetModel and toEntity(targetModel) or nil
		local weaponTable = attackData.weapon or {}

		-- 🔥 DEATHBLOW CHECK
		if targetModel and canDeathblow(character, targetModel) then
			if CombatService.PerformDeathblow then
				CombatService.PerformDeathblow(attackerEntity, targetEntity)
				return
			end
		end

		-- Normal attack
		CombatService.ProcessAttack(attackerEntity, targetEntity, weaponTable)
	end)
end

-- =========================
-- GUARD / BLOCK DAMAGE
-- =========================
local GuardRemote = CombatRemotes:FindFirstChild("GuardEvent")
if GuardRemote then
	GuardRemote.OnServerEvent:Connect(function(player, guardData)
		if not player or not player:IsA("Player") then return end
		local character = player.Character
		if not character then return end

		guardData = guardData or {}
		local entity = toEntity(character)
		local amount = guardData.amount or 0

		CombatService.ApplyGuardDamage(entity, amount)
	end)
end

-- =========================
-- TARGET LOCK
-- =========================
local TargetLockRemote = CombatRemotes:FindFirstChild("TargetLockEvent")
if TargetLockRemote then
	TargetLockRemote.OnServerEvent:Connect(function(player, lockData)
		if not player or not player:IsA("Player") then return end
		local character = player.Character
		if not character then return end

		lockData = lockData or {}
		CombatService.ValidateLockOn(
			lockData.attackerPos,
			lockData.targetPos,
			lockData.attackerForward
		)
	end)
end
