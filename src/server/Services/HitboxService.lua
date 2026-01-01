-- HitboxService.lua
-- Server-side validation for hitbox checks
-- SOURCE OF TRUTH for hit validation (range / angle / timing)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

return HitboxService
