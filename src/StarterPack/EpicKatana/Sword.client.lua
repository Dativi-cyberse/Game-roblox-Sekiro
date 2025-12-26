-- Sword.client.lua
-- LocalScript placed under StarterPack/EpicKatana (parent should be the Tool)
-- Plays slash combo animations using AnimationIds stored in
-- ReplicatedStorage/Assets/Animations/* ModuleScripts.
-- Uses Humanoid.Animator only and never parents Animation objects into Explorer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local tool = script.Parent

-- Order must match Shared/Assets/Animations folder names
local SLASH_ORDER = { "Slash1", "Slash2", "Slash3", "Slash4", "Slash5" }
local COMBO_MAX = #SLASH_ORDER
local COMBO_RESET_TIME = 1.5
local CLIENT_COOLDOWN = 0.12

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local combatRemotes = remotes:WaitForChild("Combat")
local m1Remote = combatRemotes:WaitForChild("M1Event")

local assets = ReplicatedStorage:WaitForChild("Assets")
local animsFolder = assets:WaitForChild("Animations")

local slashModules = {}
for i, name in ipairs(SLASH_ORDER) do
    local mod = animsFolder:WaitForChild(name)
    slashModules[i] = require(mod)
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

local function ensureAnimator(character)
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

local function makeAnimationInstance(animModule)
    local a = Instance.new("Animation")
    a.Name = "_TempAnim"
    a.AnimationId = "rbxassetid://" .. tostring(animModule.AnimationId)
    -- Set priority on the Animation instance before loading it into the Animator.
    -- AnimationPriority must be set on the Animation (not the track) so it overrides
    -- lower-priority Animate/idle animations. This is required for Studio 2025.
    a.Priority = animModule.AnimationPriority or Enum.AnimationPriority.Action
    return a
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

local function onMarkerHit(markerName)
    if markerName == "Hit" then
        local safeIndex = math.clamp(comboIndex, 1, COMBO_MAX)
        -- Notify server for hit processing; server must validate
        pcall(function()
            m1Remote:FireServer(safeIndex)
        end)
    end
end

local function playComboAnimation()
    if isAttacking then return end
    local char = player.Character
    if not char then return end
    local animator = ensureAnimator(char)
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
        warn("[Sword.client] Failed to load animation for combo index:", comboIndex)
        -- Continue with attack logic even without animation
        isAttacking = false
        comboIndex = math.min(COMBO_MAX, comboIndex + 1)
        scheduleComboReset()
    end
end

-- Tool events
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
    warn("Sword.client.lua: parent is not a Tool; ensure this LocalScript is a child of the EpicKatana Tool in StarterPack or the player's Backpack.")
end

-- Handle character respawn
player.CharacterAdded:Connect(function(char)
    comboIndex = 1
    isAttacking = false
    cleanupTrack()
    clearComboReset()
end)

-- Sanity check
for i=1,COMBO_MAX do
    if not slashModules[i] then
        warn("Sword client: missing animation module for index", i)
    end
end

print("EpicKatana client loaded — ready")
