local ServerScriptService = game:GetService("ServerScriptService")
local Services = ServerScriptService:WaitForChild("Services")

local CombatService = require(Services:WaitForChild("CombatService"))
local PlayerStateService = require(Services:WaitForChild("PlayerStateService"))

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:FindFirstChild("Shared")
if not Shared then return end

local Remotes = Shared:FindFirstChild("Remotes")
if not Remotes then return end

local CombatRemotes = Remotes:FindFirstChild("Combat")
if not CombatRemotes then return end



-- =========================
-- CONFIG
-- =========================
local DEATHBLOW_RANGE = 6
local DEATHBLOW_ANGLE_DOT = 0.2 -- càng thấp càng dễ deathblow từ sau

local function getEntityFromModel(model)
    local ps = PlayerStateService.GetEntityFromCharacter(model)
    if ps then return ps end
    return _G.NPC_ENTITIES and _G.NPC_ENTITIES[model]
end
local function toEntity(model)
	return getEntityFromModel(model)
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
		if not attackData.isAttack then return end -- HOTFIX
local targetModel = attackData.target
local attackerEntity = PlayerStateService.GetPlayerEntity(player)
local targetEntity = getEntityFromModel(targetModel)

-- HOTFIX: Acquire target if nil
if not targetEntity then
    -- HOTFIX
    local attackerRoot = getRoot(character)
    if attackerRoot then
        local closestDist = math.huge
        local closestEntity = nil
        for _, entity in pairs(_G.NPC_ENTITIES or {}) do
            local model = entity.Model -- HOTFIX
            local root = getRoot(model) -- HOTFIX
            if root then -- HOTFIX
                local dist = (attackerRoot.Position - root.Position).Magnitude -- HOTFIX
                if dist <= 8 and dist < closestDist then -- HOTFIX
                    closestDist = dist -- HOTFIX
                    closestEntity = entity -- HOTFIX
                end -- HOTFIX
            end -- HOTFIX
        end -- HOTFIX
        targetEntity = closestEntity
    end
end

local weaponTable = attackData.weapon or {}

		-- 🔥 DEATHBLOW CHECK
		if targetModel and canDeathblow(character, targetModel) then
			if CombatService.PerformDeathblow then
				CombatService.PerformDeathblow(attackerEntity, targetEntity)
				return
			end
		end

		-- Normal attack
		local now = os.clock() -- HOTFIX
		if attackerEntity._lastAttackTime and (now - attackerEntity._lastAttackTime) < 0.35 then return end -- HOTFIX
		attackerEntity._lastAttackTime = now -- HOTFIX
		attackerEntity._attackInProgress = true -- HOTFIX
if not targetEntity then return end -- HOTFIX
CombatService.ProcessAttack(attackerEntity, targetEntity, weaponTable)
		attackerEntity._attackInProgress = nil -- HOTFIX
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

-- =========================
-- PHASE 3 & 4: DEATHBLOW HANDLER & CUTSCENE TRIGGER
-- =========================
local DeathblowRemote = CombatRemotes:FindFirstChild("Deathblow")
if DeathblowRemote then
	DeathblowRemote.OnServerEvent:Connect(function(player, payload)
		if not player or type(payload) ~= "table" or not payload.target then return end

		local attackerEntity = PlayerStateService.GetPlayerEntity(player)
		local targetModel = payload.target

		-- Get target entity (could be a Player or an NPC like the Dummy)
		local targetEntity = PlayerStateService.GetEntityFromCharacter(targetModel)
		if not targetEntity then
			-- ASSUMPTION: NPC entities are registered in a global table by their model.
			targetEntity = _G.NPC_ENTITIES and _G.NPC_ENTITIES[targetModel]
		end

		if not attackerEntity or not targetEntity then
			warn("[Deathblow] Could not find entity for attacker or target.")
			return
		end

		-- PerformDeathblow already contains the posture check, so we call it directly.
		local result = CombatService.PerformDeathblow(attackerEntity, targetEntity)

		if not result or result.outcome == "ERROR" then
			warn("[Deathblow] Failed for " .. player.Name .. ". Reason: " .. (result and result.reason or "Unknown"))
			return
		end

		-- PHASE 4: Trigger cutscene on final boss kill
		if result.outcome == "DEATHBLOW_KILL" and targetEntity.IsBoss then
			-- ASSUMPTION: A "CutsceneRemote" exists for triggering visual-only cutscenes.
			local CutsceneRemote = Remotes:FindFirstChild("CutsceneRemote") or Remotes:FindFirstChild("Interaction"):FindFirstChild("CutsceneRemote")
			if CutsceneRemote then
				-- Fire to all clients. The client-side handler will play the cutscene.
				CutsceneRemote:FireAllClients("BossDefeated", { bossModel = targetModel })
			end
		end
	end)
end
