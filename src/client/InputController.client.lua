-- InputController.client.lua
-- Thin client input forwarder
-- Sends ONLY input signals to server (no combat logic)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- =====================================================
-- REMOTES (CORRECT PATH)
-- =====================================================
local remotes = ReplicatedStorage
	:WaitForChild("Shared")
	:WaitForChild("Remotes")

local combatRemotes = remotes:WaitForChild("Combat")
local interactionRemotes = remotes:WaitForChild("Interaction")

local M1Event = combatRemotes:WaitForChild("M1Event")
local GuardEvent = combatRemotes:WaitForChild("GuardEvent")
local SprintEvent = combatRemotes:WaitForChild("SprintEvent")
local TargetLockEvent = combatRemotes:WaitForChild("TargetLockEvent")
local InteractEvent = interactionRemotes:WaitForChild("InteractEvent")

-- =====================================================
-- LOCAL COOLDOWNS (ANTI-SPAM)
-- =====================================================
local cooldowns = {}
local function checkCooldown(key, dur)
	local now = tick()
	if cooldowns[key] and now - cooldowns[key] < (dur or 0) then
		return false
	end
	cooldowns[key] = now
	return true
end

-- =====================================================
-- M1 ATTACK (CLICK / HOLD)
-- =====================================================
local m1PressTime = nil

mouse.Button1Down:Connect(function()
	if UserInputService:GetFocusedTextBox() then return end
	m1PressTime = tick()
end)

mouse.Button1Up:Connect(function()
	if not m1PressTime then return end
	if not checkCooldown("M1", 0.05) then return end

	print("M1 fired") -- ✅ DEBUG CLIENT

	M1Event:FireServer({
		press = m1PressTime,
		release = tick(),
		weapon = nil -- server decides equipped weapon
	})

	m1PressTime = nil
end)

-- =====================================================
-- GUARD / PARRY (M2 HOLD)
-- =====================================================
mouse.Button2Down:Connect(function()
	if UserInputService:GetFocusedTextBox() then return end
	if not checkCooldown("GuardStart", 0.05) then return end

	GuardEvent:FireServer({
		action = "start"
	})
end)

mouse.Button2Up:Connect(function()
	if not checkCooldown("GuardStop", 0.05) then return end

	GuardEvent:FireServer({
		action = "stop"
	})
end)

-- =====================================================
-- SPRINT / INTERACT / TARGET LOCK
-- =====================================================
local sprinting = false

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if UserInputService:GetFocusedTextBox() then return end

	if input.UserInputType == Enum.UserInputType.Keyboard then
		if input.KeyCode == Enum.KeyCode.LeftControl then
			if not sprinting then
				sprinting = true
				SprintEvent:FireServer("start")
			end

		elseif input.KeyCode == Enum.KeyCode.E then
			if not checkCooldown("Interact", 0.25) then return end
			InteractEvent:FireServer({
				target = mouse.Target
			})

		elseif input.KeyCode == Enum.KeyCode.Tab then
			if not checkCooldown("TargetLock", 0.2) then return end
			TargetLockEvent:FireServer(mouse.Target)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input, gp)
	if gp then return end

	if input.UserInputType == Enum.UserInputType.Keyboard then
		if input.KeyCode == Enum.KeyCode.LeftControl then
			if sprinting then
				sprinting = false
				SprintEvent:FireServer("stop")
			end
		end
	end
end)

-- =====================================================
-- FAILSAFE (MENU OPEN)
-- =====================================================
GuiService.MenuOpened:Connect(function()
	if sprinting then
		sprinting = false
		SprintEvent:FireServer("stop")
	end
end)

-- =====================================================
-- CHARACTER RESET
-- =====================================================
player.CharacterAdded:Connect(function()
	m1PressTime = nil
	sprinting = false
end)

return nil
