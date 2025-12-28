-- CombatClient.client.lua
-- Client-side combat controller (FSM + input + animation)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

print("CLIENT CHARACTER SCRIPT RUNNING")

-- =====================
-- MODULES
-- =====================
local StateMachine = require(script.Parent:WaitForChild("StateMachine"))
local CombatController = require(script.Parent:WaitForChild("CombatController"))
local AnimationController = require(script.Parent:WaitForChild("AnimationController"))
local DashController = require(script.Parent:WaitForChild("DashController"))

local FSMFolder = ReplicatedStorage.Shared.Modules.FSM
local IdleState   = require(FSMFolder.IdleState)
local AttackState = require(FSMFolder.AttackState)
local BlockState  = require(FSMFolder.BlockState)
local MoveState   = require(FSMFolder.MoveState)
local DashState   = require(FSMFolder.DashState)

-- =====================
-- SPRINT CONFIG
-- =====================
local BASE_SPEED = 16
local SPRINT_SPEED = 24

-- =====================
-- INIT
-- =====================
local function init(char)
	local humanoid = char:WaitForChild("Humanoid")
	local animator = humanoid:WaitForChild("Animator")
	local root = char:WaitForChild("HumanoidRootPart")
	local animate = char:FindFirstChild("Animate")

	humanoid.WalkSpeed = BASE_SPEED
	local sprinting = false

	-- Controllers
	local animationController = AnimationController.new(animator)
	local dashController = DashController.new(root)

	-- =====================
	-- FSM CONTEXT
	-- =====================
	local context = {
		Humanoid = humanoid,
		Animator = animator,
		Root = root,
		Animate = animate,
		AnimationController = animationController,

		weaponEquipped = false,
		comboIndex = 1,

		Controllers = {
			DashController = dashController,
		}
	}

	-- =====================
	-- STATES
	-- =====================
	local idle   = IdleState.new()
	local attack = AttackState.new()
	local block  = BlockState.new()
	local move   = MoveState.new()
	local dash   = DashState.new()

	context.States = {
		Idle = idle,
		Attack = attack,
		Block = block,
		Move = move,
		Dash = dash,
	}

	local fsm = StateMachine.new(idle, context)
	context.StateMachine = fsm

	local combat = CombatController.new(fsm, context)

	-- =====================================================
	-- 🔥 FSM UPDATE LOOP (QUAN TRỌNG NHẤT – TRƯỚC ĐÂY BỊ THIẾU)
	-- =====================================================
	RunService.RenderStepped:Connect(function(dt)
		if context.StateMachine then
			context.StateMachine:Update(dt)
		end
	end)

	-- =====================
	-- TOOL EQUIP
	-- =====================
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			context.weaponEquipped = true

			-- Stop all current animations
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				track:Stop(0)
			end

			-- Disable Roblox Animate
			if animate then
				animate.Disabled = true
			end

			animationController:StopAll()

			-- Decide correct state based on movement
			if humanoid.MoveDirection.Magnitude > 0.05 then
				fsm:ChangeState(context.States.Move)
			else
				animationController:PlayIdle()
				fsm:ChangeState(context.States.Idle)
			end
		end
	end)

	-- =====================
	-- TOOL UNEQUIP
	-- =====================
	char.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			context.weaponEquipped = false
			context.comboIndex = 1

			animationController:StopAll()

			-- 🔥 HARD RESET ROBLOX ANIMATE (CHẮC CHẮN HẾT KẸT)
			if animate then
				local clone = animate:Clone()
				animate:Destroy()
				clone.Parent = char
				animate = clone
				context.Animate = clone
			end

			-- Force movement refresh
			local dir = humanoid.MoveDirection
			humanoid:Move(Vector3.zero, true)
			task.wait()
			humanoid:Move(dir, true)

			fsm:ChangeState(context.States.Idle)
		end
	end)

	-- =====================
	-- INPUT
	-- =====================
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end

		-- CTRL = SPRINT
		if input.KeyCode == Enum.KeyCode.LeftControl then
			sprinting = true
			humanoid.WalkSpeed = SPRINT_SPEED
			return
		end

		-- Q = DASH
		if input.KeyCode == Enum.KeyCode.Q then
			if context.weaponEquipped then
				fsm:ChangeState(context.States.Dash)
			end
			return
		end

		-- M1 = ATTACK
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			combat:HandleM1()
			return
		end

		-- M2 = BLOCK
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			combat:SetGuarding(true)
			return
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		-- CTRL RELEASE
		if input.KeyCode == Enum.KeyCode.LeftControl then
			sprinting = false
			humanoid.WalkSpeed = BASE_SPEED
			return
		end

		-- M2 RELEASE
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			combat:SetGuarding(false)
			return
		end
	end)
end

init(character)
print("CombatClient setup complete")
