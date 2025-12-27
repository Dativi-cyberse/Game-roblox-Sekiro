local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:FindFirstChild("Shared")
if not Shared then return end
local Remotes = Shared:FindFirstChild("Remotes")
if not Remotes then return end
local CombatRemotes = Remotes:FindFirstChild("Combat")
if not CombatRemotes then return end

local CombatService = require(script.Parent.CombatService)

local function toEntity(instance)
	return {Model = instance}
end

local M1Remote = CombatRemotes:FindFirstChild("M1Event")
if M1Remote then
	M1Remote.OnServerEvent:Connect(function(player, attackData)
		if not player or not player:IsA("Player") then
			return
		end
		
		local character = player.Character
		if not character then
			return
		end
		
		attackData = attackData or {}
		local attackerEntity = toEntity(character)
		local targetEntity = attackData.target and toEntity(attackData.target) or nil
		local weaponTable = attackData.weapon or {}
		
		CombatService.ProcessAttack(attackerEntity, targetEntity, weaponTable)
	end)
end

local GuardRemote = CombatRemotes:FindFirstChild("GuardEvent")
if GuardRemote then
	GuardRemote.OnServerEvent:Connect(function(player, guardData)
		if not player or not player:IsA("Player") then
			return
		end
		
		local character = player.Character
		if not character then
			return
		end
		
		guardData = guardData or {}
		local entity = toEntity(character)
		local amount = guardData.amount or 0
		
		CombatService.ApplyGuardDamage(entity, amount)
	end)
end

local TargetLockRemote = CombatRemotes:FindFirstChild("TargetLockEvent")
if TargetLockRemote then
	TargetLockRemote.OnServerEvent:Connect(function(player, lockData)
		if not player or not player:IsA("Player") then
			return
		end
		
		local character = player.Character
		if not character then
			return
		end
		
		lockData = lockData or {}
		local attackerPos = lockData.attackerPos
		local targetPos = lockData.targetPos
		local attackerForward = lockData.attackerForward
		
		CombatService.ValidateLockOn(attackerPos, targetPos, attackerForward)
	end)
end

local ClashRemote = CombatRemotes:FindFirstChild("ClashEvent")
if ClashRemote then
	ClashRemote.OnServerEvent:Connect(function(player, clashData)
		if not player or not player:IsA("Player") then
			return
		end
		
		local character = player.Character
		if not character then
			return
		end
		
		clashData = clashData or {}
		local attackerEntity = toEntity(character)
		local targetEntity = clashData.target and toEntity(clashData.target) or nil
		local weaponTable = clashData.weapon or {}
		
		CombatService.ProcessAttack(attackerEntity, targetEntity, weaponTable)
	end)
end
