-- CombatService.server.lua
-- Server-authoritative combat logic
-- FINAL FIXED VERSION

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

print("✅ CombatService loaded")

-- =========================
-- MODULES
-- =========================
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Constants = require(Modules.Core.Constants)
local PlayerState = require(Modules.Core.PlayerState)
local WeaponData = require(Modules.Weapons.WeaponData)
local DamageCalculator = require(Modules.Combat.DamageCalculator)
local GuardParry = require(Modules.Combat.GuardParry)
local ClashResolver = require(Modules.Combat.ClashResolver)
local ShieldSystem = require(Modules.Combat.ShieldSystem)
local Hitbox = require(Modules.Combat.Hitbox)
local SprintModule = require(Modules.Movement.Sprint)
local TargetValidator = require(Modules.Targeting.TargetValidator)

-- =========================
-- REMOTES (ĐÚNG ĐƯỜNG DẪN)
-- =========================
local Remotes = ReplicatedStorage
	:WaitForChild("Shared")
	:WaitForChild("Remotes")

local CombatRemotes = Remotes:WaitForChild("Combat")

local M1Event = CombatRemotes:WaitForChild("M1Event")
local GuardEvent = CombatRemotes:WaitForChild("GuardEvent")
local SprintEvent = CombatRemotes:WaitForChild("SprintEvent")
local TargetLockEvent = CombatRemotes:WaitForChild("TargetLockEvent")
local ClashEvent = CombatRemotes:FindFirstChild("ClashEvent")

print("✅ M1Event ready:", M1Event)

-- =========================
-- PLAYER STATES
-- =========================
local PlayerStates = {}

local function getState(player)
	local ps = PlayerStates[player]
	if not ps then
		ps = PlayerState.new()
		PlayerStates[player] = ps
	end
	return ps
end

local function canAct(player)
	local ps = PlayerStates[player]
	if not ps then return false end
	if ps:IsDead() then return false end
	if ps.IsStunned or ps.IsGuardBroken then return false end
	return true
end

-- =========================
-- M1 ATTACK
-- =========================
local function onM1(player, payload)
	print("🔥 Server received M1 from", player.Name)

	if not canAct(player) then return end
	if type(payload) ~= "table" then return end

	local ps = getState(player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- stamina
	if ps.Stamina < Constants.Attack.StaminaCost then return end
	ps:DrainStamina(Constants.Attack.StaminaCost)
	ps:SetAttacking(true)

	-- charge
	local press = payload.press or 0
	local release = payload.release or press
	local holdTime = math.max(0, release - press)

	local chargeMul = 1
	if holdTime >= Constants.Attack.Charge.Min then
		chargeMul = math.clamp(
			holdTime / Constants.Attack.Charge.Max,
			0,
			1
		)
	end

	-- weapon
	local weaponKey = payload.weapon or "Sword"
	local weapon = WeaponData[weaponKey] or WeaponData.Sword
	local baseDamage = weapon.Damage * chargeMul

	-- hitbox
	local origin = hrp.Position + Vector3.new(0, 2, 0)
	local direction = hrp.CFrame.LookVector
	local hit = Hitbox.Raycast(origin, direction, weapon.Range, { char })

	if hit and hit.Instance then
		local targetChar = hit.Instance:FindFirstAncestorOfClass("Model")
		local targetPlayer = Players:GetPlayerFromCharacter(targetChar)

		if targetPlayer then
			local tps = getState(targetPlayer)

			-- CLASH
			if ClashResolver.Check(ps, tps) then
				ps:ApplyStun(0.4)
				tps:ApplyStun(0.4)

				if ClashEvent then
					ClashEvent:FireAllClients(hrp.Position)
				end
				return
			end

			-- PARRY
			if tps.IsParryWindowActive then
				ps:ApplyStun(0.5)
				tps:EnableCriticalWindow(1.0)
				return
			end

			-- DAMAGE
			local shieldDmg, hpDmg =
				DamageCalculator.Calculate(ps, baseDamage, tps, tps.CanCriticalStrike)

			if shieldDmg > 0 then
				ShieldSystem.ApplyGuardDamage(tps, shieldDmg)
			end
			if hpDmg > 0 then
				tps:TakeHP(hpDmg)
			end
		end
	end

	task.delay(Constants.Attack.RecoverTime or 0.2, function()
		ps:SetAttacking(false)
	end)
end

-- =========================
-- GUARD
-- =========================
local function onGuard(player, info)
	if type(info) ~= "table" then return end
	local ps = getState(player)

	if info.action == "start" then
		if not canAct(player) then return end
		ps:OpenParryWindow()
	elseif info.action == "stop" then
		ps.IsParryWindowActive = false
	end
end

-- =========================
-- SPRINT
-- =========================
local function onSprint(player, action)
	local ps = getState(player)

	if action == "start" then
		if not canAct(player) then return end
		if ps.Stamina <= 0 then return end

		ps:SetSprinting(true)
		SprintModule.Start(player)

	elseif action == "stop" then
		ps:SetSprinting(false)
		SprintModule.Stop(player)
	end
end

-- =========================
-- TARGET LOCK
-- =========================
local function onTargetLock(player, target)
	if target and TargetValidator.IsValidTarget(player, target, Constants.Targeting.MaxLockDistance) then
		player:SetAttribute("CurrentTarget", target:GetDebugId())
	else
		player:SetAttribute("CurrentTarget", "")
	end
end

-- =========================
-- TICK LOOP
-- =========================
RunService.Heartbeat:Connect(function(dt)
	for _, ps in pairs(PlayerStates) do
		ps:Tick(dt)
	end
end)

-- =========================
-- PLAYER LIFECYCLE
-- =========================
Players.PlayerAdded:Connect(function(player)
	PlayerStates[player] = PlayerState.new()
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerStates[player] = nil
	SprintModule.Stop(player)
end)

-- =========================
-- REMOTE BINDS
-- =========================
M1Event.OnServerEvent:Connect(onM1)
GuardEvent.OnServerEvent:Connect(onGuard)
SprintEvent.OnServerEvent:Connect(onSprint)
TargetLockEvent.OnServerEvent:Connect(onTargetLock)

return CombatService
-- =========================
-- END OF MODULE
-- =========================