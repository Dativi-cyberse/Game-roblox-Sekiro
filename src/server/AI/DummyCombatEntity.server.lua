-- d:\Game-roblox-Sekiro\src\server\AI\DummyCombatEntity.server.lua
-- DummyCombatEntity.server.lua
-- Automatically registers Dummy models as valid Combat Entities.
-- Ensures dummies receive damage, posture breaks, and sync health to Humanoids.
-- This file is safe to remove.

local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- [FIX] DISABLE LEGACY REGISTRATION
-- NpcRegistryService is now the SINGLE SOURCE OF TRUTH for NPC entities.
-- This prevents duplicate registration and missing EntityId mapping.
if true then
	return
end

-- 1. Dependencies
-- We assume this script is located in ServerScriptService/AI
local AI = script.Parent
local DummyEntity = require(AI:WaitForChild("DummyEntity"))

-- 2. Configuration
local DummyCombatEntity = {}
local registeredDummies = {} -- [Model] = EntityTable

-- Ensure global registry exists for CombatService
_G.NPC_ENTITIES = _G.NPC_ENTITIES or {}

-- 3. Detection Logic
local function isValidDummy(model)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then return false end
	
	-- Must have Humanoid parts
	if not model:FindFirstChild("Humanoid") then return false end
	if not model:FindFirstChild("HumanoidRootPart") then return false end
	
	-- Name check or Tag check
	if string.find(model.Name, "Dummy") then return true end
	if model:FindFirstChild("IsDummy") then return true end
	
	return false
end

local function registerDummy(model)
	-- Prevent duplicates
	if registeredDummies[model] then return end
	if _G.NPC_ENTITIES[model] then return end

	print("[DummyCombatEntity] Registering new dummy:", model.Name)

	-- Create Combat Entity Wrapper
	-- This wrapper ensures the dummy has Health, Posture, and State compatible with CombatService
	local entity = DummyEntity.new(model)
	
	-- FIX: Set EntityType for CombatService validation
	entity.EntityType = "NPC"
	entity.IsNPC = true
	print("[DummyCombatEntity] EntityType set to NPC for", model.Name)

	-- ADDED: ApplyDamage method for HitboxHandler compatibility
	function entity:ApplyDamage(data)
		local amount = data.amount or 0
		self.Health = math.max(0, self.Health - amount)
		local entityId = self.Model and self.Model:GetAttribute("EntityId") or "Unknown"
		print(string.format("[DummyCombatEntity] Damage applied | EntityId: %s | Amount: %d | HP: %d", 
			entityId, amount, self.Health))
	end

	-- Inject tracking for debug logging
	entity._lastHealth = entity.Health

	-- Register to Global System
	_G.NPC_ENTITIES[model] = entity
	registeredDummies[model] = entity

	-- Cleanup Listener
	local ancestryConn
	ancestryConn = model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			print("[DummyCombatEntity] Dummy removed:", model.Name)
			_G.NPC_ENTITIES[model] = nil
			registeredDummies[model] = nil
			if ancestryConn then ancestryConn:Disconnect() end
		end
	end)
end

-- 4. Initial Scan
for _, child in ipairs(Workspace:GetDescendants()) do
	if isValidDummy(child) then
		registerDummy(child)
	end
end

-- 5. Runtime Detection (Respawn/Insert)
Workspace.DescendantAdded:Connect(function(child)
	if isValidDummy(child) then
		-- Yield briefly to ensure children (Humanoid) are loaded
		task.delay(0.1, function()
			if child.Parent and isValidDummy(child) then
				registerDummy(child)
			end
		end)
	end
end)

-- 6. Update Loop (Heartbeat)
-- Syncs data and handles debug logs
RunService.Heartbeat:Connect(function(dt)
	for model, entity in pairs(registeredDummies) do
		-- Safety check: Are we still the owner?
		if _G.NPC_ENTITIES[model] == entity then
			
			-- Run Entity Logic (Regen posture, sync visuals)
			if entity.Update then
				entity:Update(dt)
			end
			
			-- Debug: Health Change
			if entity.Health ~= entity._lastHealth then
				local diff = entity._lastHealth - entity.Health
				print(string.format("[DummyCombatEntity] %s took %d damage! (HP: %d/%d)", 
					model.Name, diff, entity.Health, entity.MaxHealth))
				entity._lastHealth = entity.Health
			end
			
			-- Debug: Death
			if entity.Health <= 0 and not entity._deathLogged then
				print("[DummyCombatEntity] Dummy died:", model.Name)
				entity._deathLogged = true
			end
			
		else
			-- Entity was overwritten or removed externally
			registeredDummies[model] = nil
		end
	end
end)

print("[DummyCombatEntity] System Running")