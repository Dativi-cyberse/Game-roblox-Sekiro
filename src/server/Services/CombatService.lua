-- CombatService.server.lua
-- Server-authoritative combat orchestration.
-- SINGLE SOURCE OF TRUTH for damage, posture, parry, clash.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared:WaitForChild("Modules")

local Constants = require(Modules.Core.Constants)
local DamageCalculator = require(Modules.Combat.DamageCalculator)
local GuardParry = require(Modules.Combat.GuardParry)
local ClashResolver = require(Modules.Combat.ClashResolver)
local ShieldSystem = require(Modules.Combat.ShieldSystem)
local Sprint = require(Modules.Movement.Sprint)
local TargetValidator = require(Modules.Targeting.TargetValidator)
local WeaponData = require(Modules.Weapons.WeaponData)
local VFXEvent = Shared:WaitForChild("Remotes"):WaitForChild("Combat"):WaitForChild("VFXEvent")
local CombatService = {}

CombatService.Config = {
	Weapons = {},
}

local function now()
	return os.clock()
end

local function isEntity(e)
	return type(e) == "table"
end

local function getEntityName(e)
	if not isEntity(e) then return "nil" end
	if e.EntityId then return tostring(e.EntityId) end
	if e.Model and e.Model.Name then return e.Model.Name end
	if e.Character and e.Character.Name then return e.Character.Name end
	return "Unknown"
end

-- =========================
-- GUARD / POSTURE DAMAGE
-- =========================
function CombatService.ApplyGuardDamage(entity, amount)
	if not isEntity(entity) or type(amount) ~= "number" then return end

	local amt = math.max(0, amount)

	if entity.Shield ~= nil then
		entity.Shield = math.max(0, (entity.Shield or 0) - amt)
		if entity.Shield <= 0 then
			entity._isGuardBroken = true
			entity._staggerUntil = math.max(entity._staggerUntil or 0, now() + 0.6)
		end
		return
	end

	if entity.Guard ~= nil then
		entity.Guard = math.max(0, (entity.Guard or 0) - amt)
		if entity.Guard <= 0 then
			entity._isGuardBroken = true
			entity._staggerUntil = math.max(entity._staggerUntil or 0, now() + 0.6)
		end
		return
	end

	if entity.Posture ~= nil then
		entity.Posture = math.clamp(
			(entity.Posture or Constants.POSTURE_MAX) - amt,
			0,
			Constants.POSTURE_MAX
		)
		if entity.Posture <= 0 then
			entity._staggerUntil = math.max(entity._staggerUntil or 0, now() + 0.6)
		end
		return
	end

	entity.Health = math.max(0, (entity.Health or 0) - math.floor(amt * 0.2))
end

-- =========================
-- APPLY DAMAGE RESULTS (FIXED LỖI KHÔNG MẤT MÁU)
-- =========================
local function applyDamageResults(attacker, defender, res)
	if not isEntity(defender) or type(res) ~= "table" then return end

	-- 1. Trừ máu logic (Table Health) & Đồng bộ xuống Humanoid
	if res.hpToDefender and type(res.hpToDefender) == "number" then
		defender.Health = math.max(0, (defender.Health or 0) - res.hpToDefender)
		
		-- [FIX]: Trừ máu thực tế trên Roblox Model để UI cập nhật!
		if defender.Humanoid then
			defender.Humanoid:TakeDamage(res.hpToDefender)
		end
	end

	-- 2. Trừ Posture (Giữ nguyên logic cũ của đệ)
	if res.postureToDefender and type(res.postureToDefender) == "number" then
		if defender.Posture ~= nil then
			defender.Posture = math.clamp(
				(defender.Posture or Constants.POSTURE_MAX) - res.postureToDefender,
				0,
				Constants.POSTURE_MAX
			)
			if defender.Posture <= 0 then
				defender._staggerUntil = math.max(defender._staggerUntil or 0, now() + 1.0)
			end
		else
			CombatService.ApplyGuardDamage(defender, res.postureToDefender)
		end
	end

	-- 3. Trừ Posture Attacker (Giữ nguyên logic)
	if res.postureToAttacker and type(res.postureToAttacker) == "number" then
		if attacker and attacker.Posture ~= nil then
			attacker.Posture = math.clamp(
				(attacker.Posture or Constants.POSTURE_MAX) - res.postureToAttacker,
				0,
				Constants.POSTURE_MAX
			)
			if attacker.Posture <= 0 then
				attacker._staggerUntil = math.max(attacker._staggerUntil or 0, now() + 1.0)
			end
		else
			CombatService.ApplyGuardDamage(attacker or {}, res.postureToAttacker)
		end
	end
end

-- =========================
-- MAIN ATTACK ENTRY
-- =========================
function CombatService.ProcessAttack(attackerEntity, targetEntity, weaponTable)
	-- [DEBUG] Log IDs
	local aId = getEntityName(attackerEntity)
	local tId = getEntityName(targetEntity)
	local atkId = weaponTable and weaponTable.attackId or "nil"
	
	print(string.format("[CombatService] ProcessAttack: %s -> %s [AttackID: %s]", aId, tId, atkId))

	-- [MUGEN FIX] Strict Entity Validation
	if not isEntity(attackerEntity) or not isEntity(targetEntity) or not attackerEntity.RootPart or not targetEntity.RootPart then
		return { outcome = "ERROR", reason = "Invalid entities" }
	end

	local weapon = WeaponData.Normalize(weaponTable or {})
	local attackTime = now()

	-- [FIX] Prevent multi-hit damage using Attack ID
	local attackId = weaponTable.attackId
	if attackId then
		attackerEntity._processedAttacks = attackerEntity._processedAttacks or {}
		local key = attackId .. "_" .. (targetEntity.EntityId or tostring(targetEntity.Model))
		if attackerEntity._processedAttacks[key] then
			return { outcome = "IGNORED", reason = "Duplicate hit" }
		end
		attackerEntity._processedAttacks[key] = true
		
		-- Cleanup old attack IDs periodically (simple approach)
		task.delay(5, function()
			if attackerEntity._processedAttacks then
				attackerEntity._processedAttacks[key] = nil
			end
		end)
	end

	-- [FIX] Range Check (Server Authoritative)
	local dist = (attackerEntity.RootPart.Position - targetEntity.RootPart.Position).Magnitude
	if dist > 12 then 
		return { outcome = "MISS", reason = "Out of range" }
	end

	-- [FIX] NPC Damage Scaling vs Player
	if attackerEntity.IsNPC and targetEntity.EntityType == "PLAYER" then
		-- Tăng lên 0.7 hoặc bỏ luôn nếu muốn test sát thương thật
		weapon.Damage = math.max(1, math.floor((weapon.Damage or 15) * 0.7)) 
	end
	if not weapon.Damage or weapon.Damage <= 0 then
		weapon.Damage = 5 
	end

	-- =========================
	-- PARRY CHECK
	-- =========================
	local parryOutcome
	if type(targetEntity.parryIntentTime) == "number" then
		parryOutcome = GuardParry.ResolveParry(targetEntity, attackTime)
	end

	if parryOutcome and parryOutcome.outcome == "PARRY" then
		if parryOutcome.posturePenalty and type(parryOutcome.posturePenalty) == "number" then
			if targetEntity.Posture ~= nil then
				targetEntity.Posture = math.clamp(
					(targetEntity.Posture or Constants.POSTURE_MAX) - parryOutcome.posturePenalty,
					0,
					Constants.POSTURE_MAX
				)
			else
				CombatService.ApplyGuardDamage(targetEntity, parryOutcome.posturePenalty)
			end
		end

		local calc = DamageCalculator.Calculate(
			attackerEntity,
			targetEntity,
			weapon,
			{ wasParried = true }
		)

		applyDamageResults(attackerEntity, targetEntity, calc)

		return { outcome = "PARRIED", calc = calc }
	end

	-- =========================
	-- GUARD CHECK (FIXED LỖI XUYÊN THỦ)
	-- =========================
	local isGuarding = false
	
	-- Quét sạch mọi biến trạng thái thủ có thể có
	local isBlockingState = false
	if targetEntity.StateMachine and targetEntity.StateMachine.CurrentState then
		isBlockingState = (targetEntity.StateMachine.CurrentState.Name == "Blocking" or targetEntity.StateMachine.CurrentState.Name == "Guarding")
	end
	
	if targetEntity.IsGuarding or targetEntity._isGuarding or targetEntity.IsBlocking or targetEntity._isBlocking or targetEntity._isParrying or isBlockingState then
		isGuarding = true
	end

	-- =========================
	-- CLASH CHECK
	-- =========================
	if attackerEntity._lastAttackTime and targetEntity._lastAttackTime and not attackerEntity.IsNPC then
		local aHit = { hitTime = attackerEntity._lastAttackTime, weapon = weapon }
		local dHit = { hitTime = targetEntity._lastAttackTime, weapon = targetEntity.weapon or {} }

		local clash = ClashResolver.Resolve(aHit, dHit)
		if clash and clash.outcome then
			local calc = DamageCalculator.Calculate(
				attackerEntity,
				targetEntity,
				weapon,
				{ clashOutcome = clash.outcome }
			)

			applyDamageResults(attackerEntity, targetEntity, calc)

			return { outcome = "CLASH", clash = clash, calc = calc }
		end
	end

	-- =========================
	-- NORMAL HIT CALCULATION
	-- =========================
	local calc = DamageCalculator.Calculate(
		attackerEntity,
		targetEntity,
		weapon,
		{ isGuarding = isGuarding }
	)

	-- =========================
	-- FINISHER KNOCKBACK & STATE UPDATE (JJS/MUGEN STYLE)
	-- =========================
	local isFinisher = (weaponTable and weaponTable.comboIndex == 4) or weaponTable.IsFinisher
	
	-- Áp dụng sát thương cuối cùng
	applyDamageResults(attackerEntity, targetEntity, calc)

	if (targetEntity.Posture and targetEntity.Posture <= 0) or targetEntity._isGuardBroken then
		targetEntity._staggerUntil = math.max(targetEntity._staggerUntil or 0, now() + 1.0)
	end

	-- =========================
	-- TENACITY REACTION LOGIC (BOSS VS MOB)
	-- =========================
	local isBoss = targetEntity.IsBoss or targetEntity.EntityType == "BOSS"
	local shouldStun = true -- Mặc định là bị khựng
	
	if isBoss then
		-- Nếu là Boss, chỉ bị khựng khi Posture về 0 (hoặc là đòn Finisher hất văng)
		if (targetEntity.Posture and targetEntity.Posture > 0) and not isFinisher then
			shouldStun = false
			print("[CombatService] Boss absorbed hit (Tenacity active) - No Flinch!")
		end
	end

	-- Xử lý Vật lý (Ragdoll/Knockback)
	if targetEntity.RootPart and attackerEntity.RootPart then
		if isFinisher then
			-- [JJS STYLE] Hất văng
			local dir = targetEntity.RootPart.Position - attackerEntity.RootPart.Position
			if dir.Magnitude < 0.1 then
				dir = attackerEntity.RootPart.CFrame.LookVector
			end
			
			dir = Vector3.new(dir.X, 0, dir.Z).Unit
			local knockbackDir = (dir + Vector3.new(0, 0.35, 0)).Unit -- Hất chếch lên trên

			targetEntity.RootPart.Anchored = false
			targetEntity.RootPart.AssemblyLinearVelocity = knockbackDir * 100 -- Lực đập mạnh

			-- Ragdoll NPC
			if targetEntity.Humanoid then
				targetEntity.Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
				targetEntity.Humanoid.PlatformStand = true
				
				task.delay(1.5, function() -- Thời gian nằm sân dài
					if targetEntity.Humanoid and targetEntity.Humanoid.Health > 0 then
						targetEntity.Humanoid.PlatformStand = false
						targetEntity.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
					end
				end)
			end
		elseif shouldStun then
			-- Chỉ reset Velocity (khựng vật lý) nếu mục tiêu thực sự bị stun
			targetEntity.RootPart.AssemblyLinearVelocity = Vector3.new(0,0,0)
		end
	end

	-- Ép mục tiêu chuyển State sang HitStun (Đồng bộ FSM)
	if shouldStun and targetEntity.StateMachine then
		-- Gắn data để HitStunState biết có phải Finisher hay không
		targetEntity.lastHitData = {
			IsFinisher = isFinisher,
			AttackerCFrame = attackerEntity.RootPart.CFrame
		}
		
		if targetEntity.States and targetEntity.States.HitStun then
			targetEntity.StateMachine:ChangeState(targetEntity.States.HitStun)
		end
	end

	attackerEntity._lastAttackTime = attackTime

	-- =========================
	-- [VFX/SFX] BÓP CÒ GỬI TÍN HIỆU VỀ CLIENT
	-- =========================
	local hitType = "NormalHit"
	
	if isGuarding then
		hitType = "Blocked"       -- Nếu đang thủ -> Báo Keng
	elseif isFinisher then
		hitType = "FinisherHit"   -- Nếu là đòn thứ 4 -> Báo Nổ/Chí mạng
	elseif isBoss and not shouldStun then
		hitType = "SuperArmor"    -- Boss lỳ đòn -> Báo Đánh vào đá
	end

	-- Lấy Model của Dummy/Mục tiêu và vị trí chém
	local targetChar = targetEntity.Character or targetEntity.Model
	local hitPosition = targetEntity.RootPart and targetEntity.RootPart.Position

	if targetChar and hitPosition then
		VFXEvent:FireAllClients(hitType, targetChar, hitPosition)
		print("[CombatService] ĐÃ BÓP CÒ VFX:", hitType)
	end
	-- =========================

	return { outcome = "HIT", calc = calc }
end

-- =========================
-- LOCK-ON / MOVEMENT
-- =========================
function CombatService.ValidateLockOn(attackerPos, targetPos, attackerForward)
	return TargetValidator.ValidateLockOn(attackerPos, targetPos, attackerForward)
end

function CombatService.CanStartSprint(playerState)
	if not isEntity(playerState) then return false end
	return Sprint.CanStart(playerState)
end

function CombatService.TickSprint(playerState, dt)
	if not isEntity(playerState) then return false end
	return Sprint.Tick(playerState, dt)
end

-- =========================
-- POSTURE / DEATHBLOW
-- =========================
function CombatService.IsPostureBroken(entity)
	if not isEntity(entity) then return false end

	if entity.Posture ~= nil then
		return entity.Posture <= 0
	end

	if entity.Shield ~= nil then
		return entity.Shield <= 0
	end

	if entity.Guard ~= nil then
		return entity.Guard <= 0
	end

	if entity._staggerUntil and entity._staggerUntil > now() then
		return true
	end

	return false
end

function CombatService.PerformDeathblow(attackerEntity, targetEntity)
	if not isEntity(attackerEntity) or not isEntity(targetEntity) then
		return { outcome = "ERROR", reason = "Invalid entities" }
	end

	if not CombatService.IsPostureBroken(targetEntity) then
		return { outcome = "ERROR", reason = "Target posture not broken" }
	end

	if targetEntity.IsBoss
		and type(targetEntity.Lives) == "number"
		and targetEntity.Lives > 1 then

		targetEntity.Lives -= 1

		local damage = (targetEntity.MaxHealth or 100) * 0.2
		targetEntity.Health = math.max(0, targetEntity.Health - damage)

		targetEntity.Posture = targetEntity.MaxPosture or 100
		targetEntity._staggerUntil = now() + 1.5

		return {
			outcome = "DEATHBLOW_PHASE",
			remainingLives = targetEntity.Lives,
		}
	end

	targetEntity.Health = 0
	targetEntity._isDead = true
	targetEntity.State = "Dead"

	return { outcome = "DEATHBLOW_KILL" }
end

return CombatService