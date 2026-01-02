-- HitboxService.lua
-- Server-side validation for hitbox checks
-- SOURCE OF TRUTH for hit validation (range / angle / timing)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared:WaitForChild("Modules")

local WeaponData = require(Modules.Weapons.WeaponData)

local HitboxService = {}

local MAX_ANGLE_DOT = 0.5
local MIN_COMBO_INTERVAL = 0.12

-- =====================================================
-- VALIDATE HIT
-- =====================================================
function HitboxService.ValidateHit(attackerEntity, targetEntity, attackData)
	if not attackerEntity or not targetEntity then
		return false, "Invalid entities"
	end

	local now = os.clock()

	-- =========================
	-- COMBO MULTI-HIT GATE
	-- =========================
	local comboIndex = attackerEntity._currentComboIndex or 0
	local lastComboIndex = attackerEntity._lastComboIndex
	local lastHitTime = attackerEntity._lastComboHitTime or 0

	-- [MUGEN SAFE CHANGE]
	-- Block spam of SAME combo hit
	-- Allow natural progression: 1 -> 2 -> 3 -> 4
	if lastComboIndex == comboIndex then
		if now - lastHitTime < MIN_COMBO_INTERVAL then
			return false, "Combo hit cooldown"
		end
	end

	-- record combo hit info AFTER validation
	attackerEntity._lastComboIndex = comboIndex
	attackerEntity._lastComboHitTime = now

	-- =========================
	-- TIMING
	-- =========================
	local referenceTime =
		attackerEntity._lastAttackIntentTime
		or attackerEntity._lastAttackTime
		or 0

	if now - referenceTime > 1.0 then
		return false, "Attack timing expired"
	end

	if attackerEntity.State == "Staggered"
		or attackerEntity.State == "Dead" then
		return false, "Attacker incapacitated"
	end

	-- =========================
	-- ROOT PARTS
	-- =========================
	local aRoot = attackerEntity.RootPart
	local tRoot = targetEntity.RootPart
	if not aRoot or not tRoot then
		return false, "Missing root parts"
	end

	-- =========================
	-- WEAPON DATA (SERVER AUTHORITATIVE)
	-- =========================
	local weaponId = attackData and attackData.weaponId
	local weaponConfig = weaponId and WeaponData.Get(weaponId)

	-- fallback range if weapon missing
	local range = (weaponConfig and weaponConfig.Range) or 6

	-- =========================
	-- DISTANCE
	-- =========================
	if (aRoot.Position - tRoot.Position).Magnitude > (range + 2) then
		return false, "Out of range"
	end

	-- =========================
	-- ANGLE
	-- =========================
	local toTarget = (tRoot.Position - aRoot.Position).Unit
	if aRoot.CFrame.LookVector:Dot(toTarget) < MAX_ANGLE_DOT then
		return false, "Not facing target"
	end

	return true, "Valid"
end

-- =====================================================
-- NPC SERVER HITBOX (SPAWN)
-- =====================================================
function HitboxService.SpawnNpcHitbox(attackerEntity, weaponData)
	if not attackerEntity or not attackerEntity.RootPart then return end

	-- Lazy load to avoid cyclic dependency
	local Services = ServerScriptService:WaitForChild("Services")
	local CombatService = require(Services.CombatService)
	local PlayerStateService = require(Services.PlayerStateService)

	local root = attackerEntity.RootPart
	local weapon = weaponData or {}
	local range = weapon.Range or 6
	local width = weapon.Width or 5

	local size = Vector3.new(width, 6, range)
	local cframe = root.CFrame * CFrame.new(0, 0, -range * 0.5)
	
	local params = OverlapParams.new()
	params.FilterDescendantsInstances = {attackerEntity.Character or attackerEntity.Model}
	params.FilterType = Enum.RaycastFilterType.Exclude

	local parts = workspace:GetPartBoundsInBox(cframe, size, params)
	local hitEntities = {}

	for _, part in ipairs(parts) do
		local char = part.Parent
		if char and char:FindFirstChild("Humanoid") then
			-- 1. Try NPC Registry (Global)
			local targetEntity = _G.NPC_ENTITIES and _G.NPC_ENTITIES[char]

			-- 2. Try Player Registry (PlayerStateService) if not found
			if not targetEntity then
				targetEntity = PlayerStateService.GetEntityFromCharacter(char)
			end
			
			if targetEntity and targetEntity ~= attackerEntity and not hitEntities[targetEntity] then
				hitEntities[targetEntity] = true
				
				-- Validate Angle
				local toTarget = (targetEntity.RootPart.Position - root.Position).Unit
				if root.CFrame.LookVector:Dot(toTarget) >= MAX_ANGLE_DOT then
					local targetName = (targetEntity.Character and targetEntity.Character.Name) 
						or (targetEntity.Model and targetEntity.Model.Name) 
						or "Unknown"

					print("[HitboxService] NPC hit PlayerEntity", targetName)
					
					local result = CombatService.ProcessAttack(attackerEntity, targetEntity, weapon)
					print("[HitboxService] ProcessAttack Result:", result and result.outcome)
					
					-- [FIX] Consume hitbox after first valid hit (Single Target / No Multi-proc)
					break
				end
			end
		end
	end
end

return HitboxService
