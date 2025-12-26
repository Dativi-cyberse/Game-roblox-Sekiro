-- CombatRemoteHandler.server.lua
-- Server-side handler for combat RemoteEvents
-- WHY: Separates RemoteEvent handling from CombatService logic

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = Shared:WaitForChild("Remotes")
local CombatRemotes = Remotes:WaitForChild("Combat")

local CombatService = require(script.Parent.CombatService)

-- =====================================================
-- ATTACK REMOTE
-- =====================================================

local AttackRemote = CombatRemotes:WaitForChild("Attack")
AttackRemote.OnServerEvent:Connect(function(player, attackData)
	-- Validate player
	if not player or not player:IsA("Player") then
		return
	end
	
	local character = player.Character
	if not character then
		return
	end
	
	-- Validate attack data
	attackData = attackData or {}
	
	-- Process attack (server decides targets)
	local result = CombatService.ProcessAttack(character, nil)
	
	-- Fire back to client for feedback (optional)
	if result.success then
		-- Could send damage numbers, hit effects, etc.
	end
end)

-- =====================================================
-- PARRY REMOTE
-- =====================================================

local ParryRemote = CombatRemotes:WaitForChild("Parry")
ParryRemote.OnServerEvent:Connect(function(player)
	-- Validate player
	if not player or not player:IsA("Player") then
		return
	end
	
	local character = player.Character
	if not character then
		return
	end
	
	-- Record parry intent
	CombatService.ProcessParryIntent(character)
end)

-- =====================================================
-- BLOCK REMOTE
-- =====================================================

local BlockRemote = CombatRemotes:WaitForChild("Block")
BlockRemote.OnServerEvent:Connect(function(player, blockData)
	-- Validate player
	if not player or not player:IsA("Player") then
		return
	end
	
	local character = player.Character
	if not character then
		return
	end
	
	-- Block data should contain action: "start" or "stop"
	blockData = blockData or {}
	local action = blockData.action or "start"
	
	if action == "start" then
		CombatService.StartBlock(character)
	elseif action == "stop" then
		CombatService.EndBlock(character)
	end
end)

-- =====================================================
-- DEATHBLOW REMOTE
-- =====================================================

local DeathblowRemote = CombatRemotes:WaitForChild("Deathblow")
DeathblowRemote.OnServerEvent:Connect(function(player, targetData)
	-- Validate player
	if not player or not player:IsA("Player") then
		return
	end
	
	local character = player.Character
	if not character then
		return
	end
	
	-- Get target (client sends target reference, server validates)
	local target = targetData and targetData.target
	if not target or not target:IsA("Model") then
		return
	end
	
	-- Process deathblow (server validates everything)
	local success = CombatService.ProcessDeathblow(character, target)
	
	if success then
		-- Notify clients of deathblow for animation sync
		-- Could use RemoteEvent:FireAllClients() or BindableEvents
	end
end)

-- =====================================================
-- POSTURE REGENERATION LOOP
-- =====================================================

-- Run posture regeneration every frame
local RunService = game:GetService("RunService")
RunService.Heartbeat:Connect(function(deltaTime)
	CombatService.TickPostureRegeneration(deltaTime)
end)

print("[CombatRemoteHandler] Combat system initialized")


