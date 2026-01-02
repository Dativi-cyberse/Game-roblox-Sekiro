-- AttackState.lua
-- Mugen-style combo attack state

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Services = ServerScriptService:FindFirstChild("Services")
local CombatService = Services and require(Services:WaitForChild("CombatService"))

local BaseState = require(script.Parent.BaseState)
local AttackState = setmetatable({}, BaseState)
AttackState.__index = AttackState

local ATTACK_DURATION = 0.45
local COMBO_BUFFER = 0.4
local MAX_COMBO = 4
local LUNGE_SPEEDS = { 50, 30, 30, 70 } -- Strong opener, light mids, heavy finisher

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
	-- print("[AttackState] Enter")

	local now = os.clock()

	self.endTime = now + ATTACK_DURATION
	self.bufferTime = self.endTime - COMBO_BUFFER

	context.comboQueued = false
	context.attackRequested = false -- Fix: Clear intent on entry to prevent immediate re-trigger
	context.isAttacking = true
	
	-- [FIX] Generate unique Attack ID to prevent multi-hit damage
	context.currentAttackId = game:GetService("HttpService"):GenerateGUID(false)

	if prevState and prevState.name == "Attack" then
		context.comboIndex = math.min((context.comboIndex or 1) + 1, MAX_COMBO)
	else
		context.comboIndex = 1
	end

	if context.AnimationController then
		context.AnimationController:PlayAttack(context.comboIndex)
	end

	-- [MUGEN MOVEMENT] Forward Lunge Impulse
	if context.Root then
		local speed = LUNGE_SPEEDS[context.comboIndex] or 30
		local forward = context.Root.CFrame.LookVector
		-- Apply horizontal velocity, preserve vertical (gravity)
		local currentY = context.Root.AssemblyLinearVelocity.Y
		context.Root.AssemblyLinearVelocity = Vector3.new(forward.X * speed, currentY, forward.Z * speed)
	end

	-- [MUGEN BOSS BEHAVIOR]
	-- NPC Damage Application (State-Based, Single Tick)
	if context.isNPC and CombatService then
		local attacker = context.Entity or (context.Controllers and context.Controllers.CombatController and context.Controllers.CombatController.entity)
		local target = context.currentTargetEntity

		-- [MUGEN FIX] Hard validation of entities
		if not attacker or not target or not attacker.RootPart or not target.RootPart then
			return
		end

		-- Rotate to face target
		if context.Root then
			local targetPos = target.RootPart.Position
			local lookDir = (targetPos - context.Root.Position).Unit
			local newCFrame = CFrame.lookAt(context.Root.Position, targetPos)
			-- Keep upright
			context.Root.CFrame = CFrame.new(context.Root.Position, Vector3.new(targetPos.X, context.Root.Position.Y, targetPos.Z))
		end

		-- Apply Damage (Once per state entry)
		local weaponData = { 
			Name = "BossKatana", 
			Damage = 15, 
			comboIndex = context.comboIndex,
			attackId = context.currentAttackId 
		}
		
		-- Use a small delay to match animation windup if desired, or instant for responsiveness
		-- For strict Mugen style, we often use instant or frame-perfect. 
		-- We'll use a tiny delay to ensure physics/positions update first.
		task.delay(0.1, function()
			if not context.isAttacking then return end -- Abort if state exited
			
			-- [MUGEN FIX] Re-validate distance at impact time
			if attacker.RootPart and target.RootPart then
				local dist = (attacker.RootPart.Position - target.RootPart.Position).Magnitude
				if dist > 8 then -- Hard cap for hit registration
					return 
				end
			end

			CombatService.ProcessAttack(attacker, target, weaponData)
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
		return -- Fix: Prevent fallthrough
	else
		context.comboIndex = 1
		context.StateMachine:ChangeState(context.States.Idle)
		return -- Fix: Prevent fallthrough
	end
end

function AttackState:Exit(nextState, context)
	context.isAttacking = false
	context.currentAttackId = nil
end

return AttackState
