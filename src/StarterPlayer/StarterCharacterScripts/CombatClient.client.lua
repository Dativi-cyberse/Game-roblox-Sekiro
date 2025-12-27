local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

print("CLIENT CHARACTER SCRIPT RUNNING")

local StateMachine = require(script.Parent:WaitForChild("StateMachine"))
local CombatController = require(script.Parent:WaitForChild("CombatController"))
local AnimationController = require(script.Parent:WaitForChild("AnimationController"))

local FSM = ReplicatedStorage.Shared.Modules.FSM
local IdleState   = require(FSM.IdleState)
local AttackState = require(FSM.AttackState)
local BlockState  = require(FSM.BlockState)
local MoveState   = require(FSM.MoveState)

local function init(char)
	local humanoid = char:WaitForChild("Humanoid")
	local animator = humanoid:WaitForChild("Animator")

	local animate = char:FindFirstChild("Animate")

	local animationController = AnimationController.new(animator)

	local context = {
		Humanoid = humanoid,
		Animator = animator,
		AnimationController = animationController,
		Animate = animate,

		weaponEquipped = false,
		comboIndex = 1,
		comboTimer = nil,
		previousMoveMagnitude = 0,
	}

	local idle   = IdleState.new()
	local attack = AttackState.new()
	local block  = BlockState.new()
	local move   = MoveState.new()

	context.States = {
		Idle = idle,
		Attack = attack,
		Block = block,
		Move = move,
	}

	local fsm = StateMachine.new(idle, context)
	context.StateMachine = fsm

	local combat = CombatController.new(fsm, context)

	-- Tool handling
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			context.weaponEquipped = true
			if animate then animate.Disabled = true end
		end
	end)

	char.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			context.weaponEquipped = false
			context.comboIndex = 1
			context.comboTimer = nil

			if animate then animate.Disabled = false end
			animationController:StopAll()
			fsm:ChangeState(idle)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			print("CLIENT M1 PRESSED")
			combat:HandleM1()
		elseif input.KeyCode == Enum.KeyCode.F then
			combat:SetGuarding(true)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.F then
			combat:SetGuarding(false)
		end
	end)
	char.ChildAdded:Connect(function(child)
	if child:IsA("Tool") then
		context.weaponEquipped = true

		-- 🔥 FIX 1: STOP TẤT CẢ TRACK (kể cả Roblox Animate)
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			track:Stop(0)
		end

		-- 🔥 FIX 2: Disable Animate SAU KHI stop
		if animate then
			animate.Disabled = true
		end

		-- 🔥 FIX 3: reset FSM về Idle combat
		context.AnimationController:StopAll()
		context.StateMachine:ChangeState(context.States.Idle)
	end
end)
end

init(character)
print("CombatClient setup complete")
