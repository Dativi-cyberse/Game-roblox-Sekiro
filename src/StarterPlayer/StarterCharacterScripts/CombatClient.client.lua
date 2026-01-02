-- CombatClient.client.lua
-- FINAL – MUGEN STYLE (SAFE PATH VERSION)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

print("CLIENT CHARACTER SCRIPT RUNNING")

-- =====================
-- SHARED FSM PATH
-- =====================
local FSMFolder = ReplicatedStorage
	:WaitForChild("Shared")
	:WaitForChild("Modules")
	:WaitForChild("FSM")

-- =====================
-- CHARACTER MODULES
-- =====================
local CombatController     = require(character:WaitForChild("CombatController"))
local AnimationController  = require(character:WaitForChild("AnimationController"))
local DashController       = require(character:WaitForChild("DashController"))
local CombatHitHandler     = require(character:WaitForChild("CombatHitHandler"))

-- =====================
-- FSM CORE + STATES
-- =====================
local StateMachine = require(FSMFolder:WaitForChild("StateMachine"))

local IdleState   = require(FSMFolder:WaitForChild("IdleState"))
local AttackState = require(FSMFolder:WaitForChild("AttackState"))
local BlockState  = require(FSMFolder:WaitForChild("BlockState"))
local MoveState   = require(FSMFolder:WaitForChild("MoveState"))
local DashState   = require(FSMFolder:WaitForChild("DashState"))

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

	local animationController = AnimationController.new(animator)
	local dashController = DashController.new(root)

	-- =====================
	-- CONTEXT (KHÔNG RÚT GỌN)
	-- =====================
	local context = {
		Humanoid = humanoid,
		Animator = animator,
		Root = root,
		Animate = animate,

		AnimationController = animationController,

		weaponEquipped = false,
		comboIndex = 1,
		comboQueued = false,
		sprintRequested = false,

		Controllers = {
			DashController = dashController,
		}
	}

	context.States = {
		Idle   = IdleState.new(),
		Attack = AttackState.new(),
		Block  = BlockState.new(),
		Move   = MoveState.new(),
		Dash   = DashState.new(),
	}

	local fsm = StateMachine.new(context.States.Idle, context)
	context.StateMachine = fsm

	local combatController = CombatController.new(fsm, context)
	context.Controllers.CombatController = combatController

	CombatHitHandler.new(context, animationController)

	RunService.RenderStepped:Connect(function(dt)
		fsm:Update(dt)
	end)

	-- =====================
	-- EQUIP / UNEQUIP
	-- =====================
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			context.weaponEquipped = true
			if animate then animate.Disabled = true end
			animationController:StopAll()
			fsm:ChangeState(context.States.Idle)
		end
	end)

	char.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			context.weaponEquipped = false
			context.comboQueued = false
			humanoid.WalkSpeed = BASE_SPEED
			animationController:StopAll()
			if animate then animate.Disabled = false end
			fsm:ChangeState(context.States.Idle)
		end
	end)

	-- =====================
	-- INPUT
	-- =====================
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end

		if input.KeyCode == Enum.KeyCode.LeftControl then
			context.sprintRequested = true
			return
		end

		if input.KeyCode == Enum.KeyCode.Q and context.weaponEquipped then
			fsm:ChangeState(context.States.Dash)
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			fsm:HandleInput("M1")
			combatController:HandleM1()
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			combatController:SetGuarding(true)
			return
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftControl then
			context.sprintRequested = false
		end

		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			combatController:SetGuarding(false)
		end
	end)
end

init(character)
print("CombatClient setup complete")
