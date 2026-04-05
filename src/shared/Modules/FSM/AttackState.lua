-- AttackState.lua
-- JJS x Mugen-style combo attack state

local RunService = game:GetService("RunService")
local isServer = RunService:IsServer()

-- An toàn: Chỉ Server mới require CombatService
local CombatService = nil
if isServer then
	local ServerScriptService = game:GetService("ServerScriptService")
	local Services = ServerScriptService:FindFirstChild("Services")
	if Services then
		CombatService = require(Services:WaitForChild("CombatService"))
	end
end

local BaseState = require(script.Parent.BaseState)
local AttackState = setmetatable({}, BaseState)
AttackState.__index = AttackState

local ATTACK_DURATION = 0.45
local COMBO_BUFFER = 0.4
local MAX_COMBO = 4
local LUNGE_SPEEDS = { 50, 30, 30, 70 } -- Đòn 1 mạnh, 2-3 nhẹ, đòn 4 (Finisher) cực mạnh

function AttackState.new()
	local self = setmetatable(BaseState.new("Attack"), AttackState)

	self.allowedTransitions = {
		Attack = true,
		Idle = true,
		HitStun = true,
		Death = true,
	}

	return self
end

function AttackState:Enter(prevState, context)
	local now = os.clock()

	self.endTime = now + ATTACK_DURATION
	self.bufferTime = self.endTime - COMBO_BUFFER

	context.comboQueued = false
	context.attackRequested = false
	context.isAttacking = true
	
	-- Generate unique Attack ID
	context.currentAttackId = game:GetService("HttpService"):GenerateGUID(false)

	-- Tăng tiến Combo
	if prevState and prevState.name == "Attack" then
		context.comboIndex = math.min((context.comboIndex or 1) + 1, MAX_COMBO)
	else
		context.comboIndex = 1
	end

	-- Phát Animation
	if context.AnimationController then
		context.AnimationController:PlayAttack(context.comboIndex)
	end

	-- [MUGEN LUNGE] - Lướt nhân vật tới trước
	if context.Root then
		local speed = LUNGE_SPEEDS[context.comboIndex] or 30
		local forward = context.Root.CFrame.LookVector
		
		-- Dùng ApplyImpulse sẽ mượt hơn AssemblyLinearVelocity trong vật lý Roblox hiện tại
		-- Nhưng nếu đệ giữ AssemblyLinearVelocity, nhớ reset X Z trước khi gán để tránh cộng dồn lực
		context.Root.AssemblyLinearVelocity = Vector3.new(forward.X * speed, context.Root.AssemblyLinearVelocity.Y, forward.Z * speed)
	end

	-- [NPC/BOSS LOGIC TÁCH BIỆT TRÊN SERVER]
	if isServer and context.isNPC and CombatService then
		local attacker = context.Entity or (context.Controllers and context.Controllers.CombatController and context.Controllers.CombatController.entity)
		local target = context.currentTargetEntity

		if not attacker or not target or not attacker.RootPart or not target.RootPart then
			return
		end

		-- Xoay NPC hướng về mục tiêu
		if context.Root then
			local targetPos = target.RootPart.Position
			context.Root.CFrame = CFrame.lookAt(context.Root.Position, Vector3.new(targetPos.X, context.Root.Position.Y, targetPos.Z))
		end

		-- Truyền dữ liệu đòn đánh
		local weaponData = { 
			Name = "BossWeapon", 
			Damage = 15, 
			comboIndex = context.comboIndex,
			attackId = context.currentAttackId,
			-- [JJS FIX] Gắn cờ đòn kết liễu
			IsFinisher = (context.comboIndex == MAX_COMBO) 
		}
		
		task.delay(0.1, function()
			if not context.isAttacking then return end 
			
			if attacker.RootPart and target.RootPart then
				local dist = (attacker.RootPart.Position - target.RootPart.Position).Magnitude
				if dist <= 8 then 
					CombatService.ProcessAttack(attacker, target, weaponData)
				end
			end
		end)
	end
end

function AttackState:HandleInput(input, context)
	if input == "M1" then
		if os.clock() >= self.bufferTime then
			context.comboQueued = true
		end
	end
end

function AttackState:Update(_, context)
	if os.clock() < self.endTime then
		return
	end

	if context.comboQueued and context.comboIndex < MAX_COMBO then
		context.comboQueued = false
		context.StateMachine:ChangeState(AttackState.new())
	else
		-- Reset combo khi về Idle
		context.comboIndex = 1
		context.StateMachine:ChangeState(context.States.Idle)
	end
end

function AttackState:Exit(nextState, context)
	context.isAttacking = false
	context.currentAttackId = nil
	-- Nếu bị ăn đòn (HitStun) giữa chừng, combo bị ngắt
	if nextState and nextState.name == "HitStun" then
		context.comboIndex = 1
	end
end

return AttackState