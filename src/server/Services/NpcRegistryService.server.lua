-- NpcRegistryService.server.lua
-- Central registry for NPC Combat Entities.
-- Maps Models <-> EntityId <-> Combat Entity tables
-- SINGLE SOURCE OF TRUTH for NPC entities

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- =========================
-- DEPENDENCIES
-- =========================

local AI = ServerScriptService:WaitForChild("AI")
local DummyEntity = require(AI:WaitForChild("DummyEntity"))

-- =========================
-- GLOBAL REGISTRIES
-- =========================

_G.NPC_ENTITIES = _G.NPC_ENTITIES or {} -- [Model] = Entity
_G.NPC_ID_MAP = _G.NPC_ID_MAP or {}     -- [EntityId] = Entity

local registeredNPCs = {}               -- local ownership tracking

-- =========================
-- PUBLIC API (GLOBAL)
-- =========================

function _G.GetCombatEntity(model)
	if not model then return nil end
	return _G.NPC_ENTITIES[model]
end

function _G.GetCombatEntityById(entityId)
	if not entityId then return nil end
	return _G.NPC_ID_MAP[entityId]
end

-- =========================
-- VALIDATION
-- =========================

local function isValidNpc(model)
	if not model:IsA("Model") then return false end
	if not model:FindFirstChild("Humanoid") then return false end
	if not model:FindFirstChild("HumanoidRootPart") then return false end

	-- Heuristic: only enemy-like models
	local name = model.Name
	if string.find(name, "Dummy")
		or string.find(name, "Sekiro")
		or string.find(name, "Enemy")
		or model:GetAttribute("IsEnemy") then
		return true
	end

	return false
end

-- =========================
-- REGISTRATION
-- =========================

local function registerNpc(model)
	if not model then return end

	-- Prevent duplicates
	if _G.NPC_ENTITIES[model] then return end
	if registeredNPCs[model] then return end

	print("[NpcRegistryService] Registering Combat Entity for:", model.Name)

	-- Create entity wrapper
	local entity = DummyEntity.new(model)

	-- Tag as NPC
	entity.EntityType = "NPC"
	entity.IsNPC = true

	-- Assign EntityId (must already be set on model)
	local entityId = model:GetAttribute("EntityId")
	entity.EntityId = entityId

	-- =========================
	-- OPTIONAL: legacy compatibility
	-- (Do NOT rely on this for main damage path)
	-- =========================
	function entity:ApplyDamage(data)
		local amount = (data and data.amount) or 0
		self.Health = math.max(0, (self.Health or 0) - amount)

		print(
			"[NpcRegistryService] ApplyDamage called (legacy)",
			"| EntityId =", self.EntityId,
			"| Amount =", amount,
			"| HP =", self.Health
		)
	end

	-- Register globally
	_G.NPC_ENTITIES[model] = entity
	registeredNPCs[model] = entity

	-- Map EntityId
	if entityId then
		_G.NPC_ID_MAP[entityId] = entity
		print("[NpcRegistryService] Mapped EntityId:", entityId)
	else
		warn("[NpcRegistryService] Model has no EntityId:", model.Name)
	end

	-- Cleanup when model is removed
	local conn
	conn = model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			_G.NPC_ENTITIES[model] = nil
			registeredNPCs[model] = nil

			if entityId then
				_G.NPC_ID_MAP[entityId] = nil
			end

			if conn then
				conn:Disconnect()
			end

			print("[NpcRegistryService] NPC removed:", model.Name)
		end
	end)
end

-- =========================
-- INITIAL SCAN
-- =========================

for _, child in ipairs(Workspace:GetDescendants()) do
	if isValidNpc(child) then
		registerNpc(child)
	end
end

-- =========================
-- RUNTIME DETECTION
-- =========================

Workspace.DescendantAdded:Connect(function(child)
	if isValidNpc(child) then
		task.delay(0.5, function()
			if child.Parent and isValidNpc(child) then
				registerNpc(child)
			end
		end)
	end
end)

-- =========================
-- UPDATE LOOP
-- =========================

RunService.Heartbeat:Connect(function(dt)
	for model, entity in pairs(registeredNPCs) do
		if _G.NPC_ENTITIES[model] == entity then
			if entity.Update then
				entity:Update(dt)
			end
		else
			registeredNPCs[model] = nil
		end
	end
end)

print("[NpcRegistryService] Running")
