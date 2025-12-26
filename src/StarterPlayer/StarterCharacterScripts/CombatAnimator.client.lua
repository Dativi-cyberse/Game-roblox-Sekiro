-- CombatAnimator.client.lua
-- LocalScript placed in StarterPlayer/StarterCharacterScripts
-- Plays combat animations on the client using Humanoid.Animator only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- Do NOT use UserInputService here; InputController/Tools handle input forwarding.

local player = Players.LocalPlayer
local SLASH_ORDER = { "Slash1", "Slash2", "Slash3", "Slash4", "Slash5" }
local COMBO_MAX = #SLASH_ORDER
local COMBO_RESET_TIME = 1.5
local CLIENT_COOLDOWN = 0.12

-- Animations located at ReplicatedStorage.Shared.Assets.Animations
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
    -- Module returns Id as a full AnimationId string (e.g. "rbxassetid://123...")
    a.AnimationId = animModule.Id
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
    -- Set priority on the AnimationTrack so it takes effect in Studio 2025
    track.Priority = animModule.Priority or Enum.AnimationPriority.Action
    currentTrack = track

    markerConnection = track:GetMarkerReachedSignal("Hit"):Connect(function(markerName)
        -- Client-only marker hook (VFX, camera shake). Do NOT fire server here;
        -- InputController forwards M1 to the server separately.
    end)

    stoppedConnection = track.Stopped:Connect(function()
        cleanupTrack()
        isAttacking = false
        comboIndex = math.min(COMBO_MAX, comboIndex + 1)
        scheduleComboReset()
    end)

    track:Play()
end
local UserInputService = game:GetService("UserInputService")

-- Use Tool.Activated/Equipped to trigger animations reliably. Input may be consumed
-- by InputController or other systems, so raw UserInputService checks are unsafe here.
local toolConnections = {}

-- Primary input path: listen for MouseButton1 so animations play immediately on the client.
local function onInputBegan(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        print("CombatAnimator: M1 pressed — triggering playComboAnimation()")
        playComboAnimation()
    end
end

UserInputService.InputBegan:Connect(onInputBegan)

local function disconnectTool(tool)
    local conns = toolConnections[tool]
    if conns then
        for _, c in pairs(conns) do
            if c and c.Disconnect then
                pcall(function() c:Disconnect() end)
            end
        end
        toolConnections[tool] = nil
    end
end

local function bindTool(tool)
    if not tool or not tool:IsA("Tool") then return end
    if toolConnections[tool] then return end
    local cons = {}
    cons.activated = tool.Activated:Connect(function()
        playComboAnimation()
    end)
    cons.equipped = tool.Equipped:Connect(function()
        -- Play-ready hook or additional setup can go here if needed
    end)
    cons.unequipped = tool.Unequipped:Connect(function()
        -- Reset combo on unequip for safety
        comboIndex = 1
        isAttacking = false
        cleanupTrack()
        clearComboReset()
    end)
    toolConnections[tool] = cons
    -- Ensure we clean up when the tool is removed from the character
    cons.removed = tool.AncestryChanged:Connect(function(_, parent)
        if not parent or not parent:IsDescendantOf(player.Character or workspace) then
            disconnectTool(tool)
        end
    end)
end

local function bindTools(character)
    if not character then return end
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Tool") then
            bindTool(child)
        end
    end
    character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            bindTool(child)
        end
    end)
end

if player.Character then
    bindTools(player.Character)
end
player.CharacterAdded:Connect(function(char)
    comboIndex = 1
    isAttacking = false
    cleanupTrack()
    clearComboReset()
    bindTools(char)
end)

for i=1,COMBO_MAX do
    if not slashModules[i] then
        warn("CombatAnimator: missing animation module for index", i)
    end
end

print("StarterCharacterScripts CombatAnimator loaded")
