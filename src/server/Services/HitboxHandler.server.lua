-- HitboxHandler.server.lua
-- Authoritative hit handler for marker-based attacks
-- Resolves targets via EntityId and forwards to CombatService ONLY
-- IMPORTANT:
-- - This file MUST NOT apply damage directly
-- - Damage is handled exclusively by CombatService

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Services = ServerScriptService:WaitForChild("Services")

local CombatService = require(Services:WaitForChild("CombatService"))
local PlayerStateService = require(Services:WaitForChild("PlayerStateService"))
local HitboxService = require(Services:WaitForChild("HitboxService"))

-- =========================
-- REMOTES (SAFE BIND – FIX)
-- =========================

local Shared
local Remotes
local CombatRemotes
local AttackRemote

-- IMPORTANT:
-- RemoteBootstrap creates remotes at runtime
-- We MUST wait until the exact AttackRemote instance exists
repeat
	Shared = ReplicatedStorage:FindFirstChild("Shared")
	Remotes = Shared and Shared:FindFirstChild("Remotes")
	CombatRemotes = Remotes and Remotes:FindFirstChild("Combat")
	AttackRemote = CombatRemotes and CombatRemotes:FindFirstChild("Attack")
	task.wait(0.05)
until AttackRemote

print("[HitboxHandler] Bound to AttackRemote:", AttackRemote:GetFullName())

-- =========================
-- ENTITY RESOLUTION
-- =========================

local function getEntity(payload)
	-- 1. Preferred: targetEntityId (NPC-safe)
	if payload.targetEntityId then
		if _G.GetCombatEntityById then
			local entity = _G.GetCombatEntityById(payload.targetEntityId)
			if entity then
				return entity
			end
		end

		if _G.NPC_ID_MAP and _G.NPC_ID_MAP[payload.targetEntityId] then
			return _G.NPC_ID_MAP[payload.targetEntityId]
		end
	end

	-- 2. Backward compatibility: payload.entityId
	if payload.entityId then
		if _G.GetCombatEntityById then
			local entity = _G.GetCombatEntityById(payload.entityId)
			if entity then
				return entity
			end
		end

		if _G.NPC_ID_MAP and _G.NPC_ID_MAP[payload.entityId] then
			return _G.NPC_ID_MAP[payload.entityId]
		end
	end

	return nil
end

-- =========================
-- MAIN HANDLER
-- =========================

AttackRemote.OnServerEvent:Connect(function(player, payload)
	if not player then return end
	if type(payload) ~= "table" then return end

	local weaponData = payload.weapon or {}
	
	-- [FIX] Pass comboIndex to CombatService for knockback logic
	if payload.comboIndex then
		weaponData.comboIndex = payload.comboIndex
	end

	-- =========================
	-- RESOLVE ATTACKER
	-- =========================

	local attackerEntity = PlayerStateService.GetPlayerEntity(player)
	if not attackerEntity then
		return
	end

	-- 🔥 CRITICAL FIX:
	-- Record attack intent time BEFORE hit validation
	attackerEntity._lastAttackIntentTime = os.clock()

	-- [MUGEN SAFE CHANGE] Sync combo index from client to server entity
	if type(payload.comboIndex) == "number" then
		attackerEntity._currentComboIndex = payload.comboIndex
	end

	-- =========================
	-- RESOLVE TARGET
	-- =========================

	local targetEntity = getEntity(payload)
	if not targetEntity then
		return
	end

	-- =========================
	-- VALIDATE ENTITY TYPE
	-- =========================

	if targetEntity.EntityType ~= "NPC"
		and targetEntity.EntityType ~= "PLAYER"
		and not targetEntity.IsNPC then
		return
	end

	-- =========================
	-- HIT VALIDATION
	-- =========================

	local valid, reason = HitboxService.ValidateHit(
		attackerEntity,
		targetEntity,
		weaponData
	)

	if not valid then
		return
	end

	-- =========================
	-- PROCESS COMBAT (SINGLE AUTHORITY)
	-- =========================

	print(
		"[HitboxHandler] Forwarding attack to CombatService",
		"TargetEntityId =",
		payload.targetEntityId or payload.entityId
	)

	CombatService.ProcessAttack(
		attackerEntity,
		targetEntity,
		weaponData
	)
end)

print("[HitboxHandler] Listening for EntityId-based attacks")
