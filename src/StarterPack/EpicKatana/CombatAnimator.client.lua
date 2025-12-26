-- CombatAnimator.client.lua
-- LocalScript (placed as a child of the EpicKatana Tool in StarterPack)
-- Responsible only for client-side combat animation playback (no networking)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local tool = script.Parent

local SLASH_ORDER = { "Slash1", "Slash2", "Slash3", "Slash4", "Slash5" }
local COMBO_MAX = #SLASH_ORDER
local COMBO_RESET_TIME = 1.5
local CLIENT_COOLDOWN = 0.12

-- Animations are stored at ReplicatedStorage.Shared.Assets.Animations (per spec)
local shared = ReplicatedStorage:WaitForChild("Shared")
local assets = shared:WaitForChild("Assets")
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
    -- Set priority on the Animation instance BEFORE loading
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
    local track = animator:LoadAnimation(animInstance)
    currentTrack = track

    -- If the animation contains markers (e.g., 'Hit') other client systems
    -- can observe them by connecting to track:GetMarkerReachedSignal here.
    markerConnection = track:GetMarkerReachedSignal("Hit"):Connect(function(markerName)
        -- deliberately do not call server events here; InputController handles input forwarding.
        -- This is a client-only hook for visual timing (e.g., VFX, camera shake).
    end)

    stoppedConnection = track.Stopped:Connect(function()
        cleanupTrack()
        isAttacking = false
        comboIndex = math.min(COMBO_MAX, comboIndex + 1)
        scheduleComboReset()
    end)

    track:Play()
end

-- Tool handling: listen for local activation (indirect M1 input)
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
    warn("CombatAnimator: parent is not a Tool; place this LocalScript under the EpicKatana Tool in StarterPack.")
end

player.CharacterAdded:Connect(function(char)
    comboIndex = 1
    isAttacking = false
    cleanupTrack()
    clearComboReset()
end)

for i=1,COMBO_MAX do
    if not slashModules[i] then
        warn("CombatAnimator: missing animation module for index", i)
    end
end

print("CombatAnimator loaded — client will play combat animations")
