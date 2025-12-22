-- InputController.client.lua
-- Safe, thin input-forwarder for client (no combat logic, no instance creation).
-- Fixes applied:
-- 1) Removed all `WaitForChild` calls that could block indefinitely.
-- 2) Replaced with non-blocking `FindFirstChild` discovery and a retry/listen strategy.
-- 3) FireServer guarded by existence checks so missing remotes don't crash or freeze input.
-- 4) Removed duplicated/legacy blocks; kept only input handling and safe remote dispatch.
-- 5) Added lightweight cooldowns and focused-textbox checks to avoid accidental input forwarding.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local mouse = player and player:GetMouse()

-- Local cached remote references (may be nil if server not yet created them)
local M1Event, GuardEvent, SprintEvent, TargetLockEvent, InteractEvent

-- Track which missing warnings we've emitted to avoid spamming output
local warned = {}

-- Utility: non-blocking find by path parts using FindFirstChild (no WaitForChild)
local function findChildPath(root, ...)
	local node = root
	for i = 1, select("#", ...) do
		if not node then
			return nil
		end
		local part = select(i, ...)
		node = node:FindFirstChild(part)
	end
	return node
end

-- Resolve remotes under ReplicatedStorage.Shared.Remotes.* (idempotent, non-blocking)
local function resolveRemotes()
	-- Try canonical path: ReplicatedStorage.Shared.Remotes.Combat/Interaction
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local remotes = shared and shared:FindFirstChild("Remotes")
	local combat = remotes and remotes:FindFirstChild("Combat")
	local interaction = remotes and remotes:FindFirstChild("Interaction")

	-- Set event handles if found and types match
	local function setIfRemote(varName, container, name)
		if not container then
			_G[varName] = nil
			return
		end
		local child = container:FindFirstChild(name)
		if child and child:IsA("RemoteEvent") then
			_G[varName] = child
		else
			_G[varName] = nil
		end
	end

	_G.M1Event = nil
	_G.GuardEvent = nil
	_G.SprintEvent = nil
	_G.TargetLockEvent = nil
	_G.InteractEvent = nil

	if combat then
		setIfRemote("M1Event", combat, "M1Event")
		setIfRemote("GuardEvent", combat, "GuardEvent")
		setIfRemote("SprintEvent", combat, "SprintEvent")
		setIfRemote("TargetLockEvent", combat, "TargetLockEvent")
	end
	if interaction then
		setIfRemote("InteractEvent", interaction, "InteractEvent")
	end

	-- Move globals into locals for faster access
	M1Event = _G.M1Event
	GuardEvent = _G.GuardEvent
	SprintEvent = _G.SprintEvent
	TargetLockEvent = _G.TargetLockEvent
	InteractEvent = _G.InteractEvent

	-- Emit concise warnings once per missing item to help debugging (non-spammy)
	local function warnOnce(key, msg)
		if not warned[key] then
			warn(msg)
			warned[key] = true
		end
	end

	if not shared then
		warnOnce("noShared", "InputController: ReplicatedStorage.Shared not found yet. Input will continue; remotes will be used when available.")
	elseif not remotes then
		warnOnce("noRemotes", "InputController: Shared.Remotes not found yet. Input will continue; remotes will be used when available.")
	else
		if not combat then
			warnOnce("noCombat", "InputController: Shared.Remotes.Combat not found yet.")
		else
			if not M1Event then warnOnce("noM1", "InputController: M1Event is missing (Shared.Remotes.Combat.M1Event).") end
			if not GuardEvent then warnOnce("noGuard", "InputController: GuardEvent is missing (Shared.Remotes.Combat.GuardEvent).") end
			if not SprintEvent then warnOnce("noSprint", "InputController: SprintEvent is missing (Shared.Remotes.Combat.SprintEvent).") end
			if not TargetLockEvent then warnOnce("noTargetLock", "InputController: TargetLockEvent is missing (Shared.Remotes.Combat.TargetLockEvent).") end
		end
		if not interaction then
			warnOnce("noInteraction", "InputController: Shared.Remotes.Interaction not found yet.")
		else
			if not InteractEvent then warnOnce("noInteract", "InputController: InteractEvent is missing (Shared.Remotes.Interaction.InteractEvent).") end
		end
	end
end

-- Fire helper: only call FireServer if event exists; protect with pcall to avoid runtime errors
local function safeFire(evt, ...)
	if not evt then
		return false
	end
	local ok, err = pcall(function(...) evt:FireServer(...) end, ...)
	if not ok then
		warn("InputController: FireServer failed:", err)
		return false
	end
	return true
end

-- Initial resolution attempt (non-blocking)
resolveRemotes()

-- Listen for runtime creation of the expected folders so we can re-resolve automatically.
-- We avoid WaitForChild and attach non-blocking listeners; these won't block execution.
ReplicatedStorage.ChildAdded:Connect(function(child)
	-- If Shared or Remotes was just added, re-resolve.
	if child.Name == "Shared" or child.Name == "Remotes" then
		-- Small defer to allow server script to finish creating children
		task.delay(0.1, resolveRemotes)
	end
end)

-- If Shared already exists, watch it for Remotes folder creation
local sharedFolder = ReplicatedStorage:FindFirstChild("Shared")
if sharedFolder then
	sharedFolder.ChildAdded:Connect(function(child)
		if child.Name == "Remotes" then
			task.delay(0.1, resolveRemotes)
		end
	end)
end

-- Periodic non-blocking retry to handle late server initialization (low-frequency)
task.spawn(function()
	while true do
		resolveRemotes()
		task.wait(5) -- safe retry interval; does not block main thread
	end
end)

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

	-- Only send if M1Event exists (safe, non-blocking)
	if M1Event then
		safeFire(M1Event, {
			press = m1PressTime,
			release = tick(),
			weapon = nil -- server decides equipped weapon
		})
	else
		-- Optional: debug print only once per session to avoid spam (resolveRemotes warns)
		-- print("InputController: M1Event not ready; attack not sent.")
	end

	m1PressTime = nil
end)

-- =====================================================
-- GUARD / PARRY (M2 HOLD)
-- =====================================================
mouse.Button2Down:Connect(function()
	if UserInputService:GetFocusedTextBox() then return end
	if not checkCooldown("GuardStart", 0.05) then return end

	if GuardEvent then
		safeFire(GuardEvent, { action = "start" })
	end
end)

mouse.Button2Up:Connect(function()
	if not checkCooldown("GuardStop", 0.05) then return end

	if GuardEvent then
		safeFire(GuardEvent, { action = "stop" })
	end
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
				if SprintEvent then safeFire(SprintEvent, "start") end
			end

		elseif input.KeyCode == Enum.KeyCode.E then
			if not checkCooldown("Interact", 0.25) then return end
			if InteractEvent then
				-- Fire minimal payload; server validates target and distance (do not trust client)
				safeFire(InteractEvent, { target = mouse and mouse.Target or nil })
			end

		elseif input.KeyCode == Enum.KeyCode.Tab then
			if not checkCooldown("TargetLock", 0.2) then return end
			if TargetLockEvent then
				safeFire(TargetLockEvent, mouse and mouse.Target or nil)
			end
		end
	end
end)

UserInputService.InputEnded:Connect(function(input, gp)
	if gp then return end

	if input.UserInputType == Enum.UserInputType.Keyboard then
		if input.KeyCode == Enum.KeyCode.LeftControl then
			if sprinting then
				sprinting = false
				if SprintEvent then safeFire(SprintEvent, "stop") end
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
		if SprintEvent then safeFire(SprintEvent, "stop") end
	end
end)

-- =====================================================
-- CHARACTER RESET
-- =====================================================
player.CharacterAdded:Connect(function()
	m1PressTime = nil
	sprinting = false
end)

-- End of InputController.client.lua (thin, safe, non-blocking)
return nil
