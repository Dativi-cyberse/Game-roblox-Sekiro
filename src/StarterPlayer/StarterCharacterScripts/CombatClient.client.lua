-- CombatClient.client.lua

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

print("CLIENT CHARACTER SCRIPT RUNNING")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StateMachine = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("FSM"):WaitForChild("StateMachine"))
print("StateMachine loaded")

local AnimationController = require(script.Parent:WaitForChild("AnimationController"))
print("AnimationController loaded")

local CombatController = require(script.Parent:WaitForChild("CombatController"))
local DashController = require(script.Parent:WaitForChild("DashController"))
local ParryController = require(script.Parent:WaitForChild("ParryController"))
local PostureController = require(script.Parent:WaitForChild("PostureController"))

-- FSM States
local IdleState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("FSM"):WaitForChild("IdleState"))
local AttackState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("FSM"):WaitForChild("AttackState"))
local BlockState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("FSM"):WaitForChild("BlockState"))
local DashState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("FSM"):WaitForChild("DashState"))
local MoveState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("FSM"):WaitForChild("MoveState"))
local ParryState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("FSM"):WaitForChild("ParryState"))
local DeathState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("FSM"):WaitForChild("DeathState"))
local HitStunState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("FSM"):WaitForChild("HitStunState"))

local stateMachine
local animationController
local combatController
local dashController
local parryController
local postureController

local inputBeganConnection
local inputEndedConnection

local function initializeModules(char)
	local humanoid = char:WaitForChild("Humanoid")
	local animator = humanoid:WaitForChild("Animator")

	-- Destroy default Animate script to prevent conflicts
	local animateScript = char:FindFirstChild("Animate")
	if animateScript then
		animateScript:Destroy()
	end

	animationController = AnimationController.new(animator)

	-- FSM Context
	local context = {
		Humanoid = humanoid,
		Animator = animator,
		AnimationController = animationController,
		comboQueued = false,
	}

	-- Create FSM states
	local idleState = IdleState.new()
	local attackState = AttackState.new()
	local blockState = BlockState.new()
	local dashState = DashState.new()
	local moveState = MoveState.new()
	local parryState = ParryState.new()
	local deathState = DeathState.new()
	local hitStunState = HitStunState.new()

	-- Initialize StateMachine with IdleState and context
	stateMachine = StateMachine.new(idleState, context)

	-- Register all states
	stateMachine:RegisterState(idleState)
	stateMachine:RegisterState(attackState)
	stateMachine:RegisterState(blockState)
	stateMachine:RegisterState(dashState)
	stateMachine:RegisterState(moveState)
	stateMachine:RegisterState(parryState)
	stateMachine:RegisterState(deathState)
	stateMachine:RegisterState(hitStunState)

	-- Set initial state to Idle (already set in constructor, but ensure)
	stateMachine:ChangeState("Idle")

	combatController = CombatController.new(stateMachine, context)
	dashController = DashController.new()
	parryController = ParryController.new()
	postureController = PostureController.new()

	print("CombatClient initialized")
end

local function cleanupModules()
	if inputBeganConnection then
		inputBeganConnection:Disconnect()
		inputBeganConnection = nil
	end
	if inputEndedConnection then
		inputEndedConnection:Disconnect()
		inputEndedConnection = nil
	end

	if animationController then
		animationController:Cleanup()
	end
	if stateMachine then
		stateMachine:Reset()
	end
	if combatController then
		combatController:Cleanup()
	end
	if dashController then
		dashController:Reset()
	end
	if parryController then
		parryController:Reset()
	end
	if postureController then
		postureController:Reset()
	end
end

local function onInputBegan(input, gameProcessed)
	if gameProcessed then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		print("CLIENT M1 PRESSED")
		combatController:HandleM1()
	elseif input.KeyCode == Enum.KeyCode.F then
		combatController:SetGuarding(true)
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		combatController:SetSprinting(true)
	end
end

local function onInputEnded(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.F then
		combatController:SetGuarding(false)
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		combatController:SetSprinting(false)
	end
end

local function onCharacterAdded(newCharacter)
	character = newCharacter
	cleanupModules()
	initializeModules(character)

	inputBeganConnection = UserInputService.InputBegan:Connect(onInputBegan)
	inputEndedConnection = UserInputService.InputEnded:Connect(onInputEnded)
end

local function onCharacterRemoving()
	cleanupModules()
end

player.CharacterAdded:Connect(onCharacterAdded)
player.CharacterRemoving:Connect(onCharacterRemoving)

if character then
	onCharacterAdded(character)
end
print("CombatClient setup complete")
