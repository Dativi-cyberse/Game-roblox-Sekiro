-- CombatServer.server.lua
-- Server-side combat bootstrap (safe, idempotent)

print("CombatServer running")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- =====================================================
-- UTILITIES
-- =====================================================

local function ensureFolder(parent, name)
    local existing = parent:FindFirstChild(name)
    if existing then
        if existing:IsA("Folder") then
            return existing
        else
            warn(("CombatServer: expected Folder at %s.%s but found %s; replacing")
                :format(parent:GetFullName(), name, existing.ClassName))
            existing:Destroy()
        end
    end

    local f = Instance.new("Folder")
    f.Name = name
    f.Parent = parent
    return f
end

local function ensureRemoteEvent(parent, name)
    local existing = parent:FindFirstChild(name)
    if existing then
        if existing:IsA("RemoteEvent") then
            return existing
        else
            warn(("CombatServer: expected RemoteEvent at %s.%s but found %s; replacing")
                :format(parent:GetFullName(), name, existing.ClassName))
            existing:Destroy()
        end
    end

    local ev = Instance.new("RemoteEvent")
    ev.Name = name
    ev.Parent = parent
    return ev
end

-- =====================================================
-- BOOTSTRAP REMOTES
-- =====================================================

local Shared = ensureFolder(ReplicatedStorage, "Shared")
ensureFolder(Shared, "Modules")

local Remotes = ensureFolder(Shared, "Remotes")
local CombatRemotes = ensureFolder(Remotes, "Combat")
local InteractionRemotes = ensureFolder(Remotes, "Interaction")

-- Combat events
local M1Event         = ensureRemoteEvent(CombatRemotes, "M1Event")
local GuardEvent      = ensureRemoteEvent(CombatRemotes, "GuardEvent")
local SprintEvent     = ensureRemoteEvent(CombatRemotes, "SprintEvent")
local ClashEvent      = ensureRemoteEvent(CombatRemotes, "ClashEvent")
local TargetLockEvent = ensureRemoteEvent(CombatRemotes, "TargetLockEvent")

-- Interaction events
local InteractEvent   = ensureRemoteEvent(InteractionRemotes, "InteractEvent")

-- =====================================================
-- SERVER LOGIC (SAFE TO CONNECT NOW)
-- =====================================================

M1Event.OnServerEvent:Connect(function(player, payload)
    print(("Server received M1 from %s"):format(player and player.Name or "Unknown"))
end)

print("CombatServer setup complete")
