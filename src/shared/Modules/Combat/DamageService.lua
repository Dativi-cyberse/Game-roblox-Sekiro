-- DamageCalculator.lua
-- Tính toán sát thương chuẩn xác cho Server (Đã fix lỗi Mismatched Variables)

local CombatConfig = require(script.Parent.Parent.Parent.CombatConfig)

local DamageCalculator = {}

function DamageCalculator.Calculate(attackerState, defenderState, weaponData, attackData)
	attackData = attackData or {}
	weaponData = weaponData or {}
	
	-- Lấy Base Damage từ vũ khí truyền vào, nếu không có thì lấy trong Config
	local baseDamage = weaponData.Damage or CombatConfig.Attack.BaseDamage or 10
	local basePosture = weaponData.PostureDamage or CombatConfig.Attack.BasePostureDamage or 15
	
	-- [JJS FIX]: Khuếch đại sát thương cho đòn Finisher
	-- Hỗ trợ đọc IsFinisher từ cả weaponData và attackData
	local isFinisher = weaponData.IsFinisher or attackData.IsFinisher or (weaponData.comboIndex == 4)
	if isFinisher then
		baseDamage = baseDamage * 1.5 -- Tăng 50% sát thương
		basePosture = basePosture * 2.0 -- Phá giáp gấp đôi
	end
	
	-- 1. KIỂM TRA PARRY
	if attackData.wasParried then
		return {
			hpToDefender = 0, 
			postureToDefender = 0, 
			postureToAttacker = CombatConfig.Parry.PostureDamage or 20, 
		}
	end
	
	-- 2. KIỂM TRA THỦ (GUARD/BLOCK)
	-- Đã fix: Nhận diện cả isGuarding và isBlocking
	local isDefending = attackData.isGuarding or attackData.isBlocking
	
	if isDefending then
		-- Giảm sát thương máu, nhưng giữ nguyên (hoặc tăng) sát thương giáp
		local reduction = CombatConfig.Block.HealthReduction or 0.2
		local postureMult = CombatConfig.Block.PostureDamageMultiplier or 1.5
		
		baseDamage = baseDamage * reduction
		basePosture = basePosture * postureMult
	end
	
	-- 3. ĐÒN KHÔNG THỂ THỦ (UNBLOCKABLE)
	if attackData.isUnblockable then
		if isDefending then
			-- Phá giáp cực mạnh nếu cố tình thủ đòn Unblockable
			basePosture = basePosture * (CombatConfig.Block.UnblockableMultiplier or 2.5)
		end
		-- Phục hồi lại sát thương máu (không bị giảm bởi Guard)
		baseDamage = weaponData.Damage or CombatConfig.Attack.BaseDamage or 10
		if isFinisher then baseDamage = baseDamage * 1.5 end
	end
	
	-- 4. TRƯỢT PARRY (FAILED PARRY)
	if attackData.failedParry then
		baseDamage = baseDamage * (CombatConfig.Parry.FailedHealthDamageMultiplier or 1.2)
		basePosture = basePosture + (CombatConfig.Parry.FailedPostureDamage or 10)
	end
	
	-- Tính toán cost cho người tấn công
	local attackerPostureCost = CombatConfig.Posture.AttackCost or 5
	if isDefending then
		attackerPostureCost = CombatConfig.Posture.BlockedAttackCost or 10
	end
	
	-- TRẢ VỀ ĐÚNG TÊN BIẾN MÀ COMBAT SERVICE ĐANG TÌM KIẾM
	return {
		hpToDefender = math.floor(baseDamage),
		postureToDefender = math.floor(basePosture),
		postureToAttacker = attackerPostureCost,
	}
end

return DamageCalculator