-- M1.client.lua
-- LocalScript placed under StarterPack/Sword
-- Plays combo animations using only AnimationIds declared in ModuleScripts
-- Requirements enforced for Studio 2025:
--  - Use `Humanoid.Animator` (do NOT use deprecated Humanoid:LoadAnimation)
--  - Do not store Animation objects in Explorer/Workspace
--  - All animation metadata lives in ModuleScripts under ReplicatedStorage/Assets/Animations

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local tool = script.Parent

-- Configuration
local SLASH_ORDER = { "Slash1", "Slash2", "Slash3", "Slash4", "Slash5" }
local COMBO_MAX = #SLASH_ORDER
local COMBO_RESET_TIME = 1.5
local CLIENT_COOLDOWN = 0.15

-- Remote (Rojo-friendly path)
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local combatRemotes = remotesFolder:WaitForChild("Combat")
local m1Remote = combatRemotes:WaitForChild("M1Event")

-- Modules folder (Rojo): ReplicatedStorage/Assets/Animations
local animsFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Animations")

-- Require the modules and keep them in order
local slashModules = {}
for i, name in ipairs(SLASH_ORDER) do
	local modInstance = animsFolder:WaitForChild(name)
	slashModules[i] = require(modInstance)
end

-- State
local comboIndex = 1
local lastClick = 0
local comboResetHandle = nil
local isAttacking = false
local currentTrack = nil
local markerConnection = nil
local stoppedConnection = nil

local function clearComboReset()
	if comboResetHandle then
		comboResetHandle = nil
	end
end

local function scheduleComboReset()
	clearComboReset()
	comboResetHandle = delay(COMBO_RESET_TIME, function()
		comboIndex = 1
		comboResetHandle = nil
	end)
end

-- Ensure Animator exists on the Humanoid
local function getAnimatorFromCharacter(character)
	if not character then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Name = "Animator"
		animator.Parent = humanoid
	end
	return animator
end

local function onMarkerHit(markerName)
	if markerName == "Hit" then
		local safeIndex = math.clamp(comboIndex, 1, COMBO_MAX)
		-- m1Remote:FireServer(safeIndex) -- HOTFIX: marker-based attack is illegal (caused phantom damage)
	end
end

local function cleanupTrack()
	if markerConnection then
		markerConnection:Disconnect()
		markerConnection = nil
	end
	if stoppedConnection then
		stoppedConnection:Disconnect()
		stoppedConnection = nil
	end
	currentTrack = nil
end

-- Create a transient Animation instance from module metadata. The Animation
-- instance is never parented into Workspace/Explorer to remain Rojo-safe.
local function makeAnimationInstance(animModule)
	local a = Instance.new("Animation")
	a.Name = "_TempAnim"
	a.AnimationId = "rbxassetid://" .. tostring(animModule.AnimationId)
	return a
end

local function playComboAnimation()
	if isAttacking then return end
	local char = player.Character
	if not char then return end
	local animator = getAnimatorFromCharacter(char)
	if not animator then return end
	local animModule = slashModules[comboIndex]
	if not animModule then return end

	if tick() - lastClick < CLIENT_COOLDOWN then return end
	lastClick = tick()

	isAttacking = true

	local animInstance = makeAnimationInstance(animModule)
	local success, track = pcall(function()
		return animator:LoadAnimation(animInstance)
	end)
	if success and track then
		-- Respect the priority supplied by the module (Action for combat)
		track.Priority = animModule.AnimationPriority or Enum.AnimationPriority.Action
		currentTrack = track

		markerConnection = track:GetMarkerReachedSignal("Hit"):Connect(function(markerName)
			onMarkerHit(markerName)
		end)

		stoppedConnection = track.Stopped:Connect(function()
			cleanupTrack()
			isAttacking = false
			comboIndex = math.min(COMBO_MAX, comboIndex + 1)
			scheduleComboReset()
		end)

		track:Play()
	else
		warn("[M1.client] Failed to load animation for combo index:", comboIndex)
		-- Continue with attack logic even without animation
		isAttacking = false
		comboIndex = math.min(COMBO_MAX, comboIndex + 1)
		scheduleComboReset()
	end
end

if tool and tool:IsA("Tool") then
	tool.Activated:Connect(function()
		local char = player.Character
		if not char then return end
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then return end
		playComboAnimation()
	end)

	tool.Unequipped:Connect(function()
		comboIndex = 1
		isAttacking = false
		cleanupTrack()
		clearComboReset()
	end)
else
	warn("M1.client.lua: script parent is not a Tool")
end

player.CharacterAdded:Connect(function(char)
	comboIndex = 1
	isAttacking = false
	cleanupTrack()
	clearComboReset()
end)

-- Sanity: ensure modules are present
for i=1,COMBO_MAX do
	if not slashModules[i] then
		warn("M1 client: missing animation module for index", i)
	end
end

print("M1 client script loaded — ready to attack (module-driven, Rojo-safe)")
