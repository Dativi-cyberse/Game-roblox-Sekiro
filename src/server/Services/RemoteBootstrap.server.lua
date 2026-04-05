-- ServerScriptService/Services/RemoteBootstrap.server.lua
-- Purpose: Guarantee all RemoteEvents exist with correct hierarchy
-- Safe, idempotent, multiplayer-ready

print("[RemoteBootstrap] Starting")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------------------------------------------------------
-- Utilities
----------------------------------------------------------------

-- Ensure a Folder exists. Replace wrong-type instances safely.
local function ensureFolder(parent, name)
    local existing = parent:FindFirstChild(name)

    if existing then
        if existing:IsA("Folder") then
            return existing
        else
            warn(("[RemoteBootstrap] Replacing non-Folder: %s"):format(existing:GetFullName()))
            existing:Destroy()
        end
    end

    local folder = Instance.new("Folder")
    folder.Name = name
    folder.Parent = parent
    return folder
end

-- Ensure a RemoteEvent exists. Replace wrong-type instances safely.
local function ensureRemoteEvent(parent, name)
    local existing = parent:FindFirstChild(name)

    if existing then
        if existing:IsA("RemoteEvent") then
            return existing
        else
            warn(("[RemoteBootstrap] Replacing non-RemoteEvent: %s"):format(existing:GetFullName()))
            existing:Destroy()
        end
    end

    local remote = Instance.new("RemoteEvent")
    remote.Name = name
    remote.Parent = parent
    return remote
end

----------------------------------------------------------------
-- Base hierarchy
----------------------------------------------------------------

-- ReplicatedStorage
-- └─ Shared
--    └─ Remotes
local Shared = ensureFolder(ReplicatedStorage, "Shared")
local Remotes = ensureFolder(Shared, "Remotes")

----------------------------------------------------------------
-- Combat Remotes (Sekiro-style)
----------------------------------------------------------------

-- ReplicatedStorage.Shared.Remotes.Combat
local Combat = ensureFolder(Remotes, "Combat")

-- Core combat actions
ensureRemoteEvent(Combat, "Attack")           -- Attack intent (from animation marker)
ensureRemoteEvent(Combat, "Parry")            -- Parry intent (timing-based)
ensureRemoteEvent(Combat, "Block")            -- Block start/stop (hold action)
ensureRemoteEvent(Combat, "Deathblow")        -- Deathblow execution

-- Legacy/Additional remotes (kept for compatibility)
ensureRemoteEvent(Combat, "M1Event")          -- light attack (legacy)
ensureRemoteEvent(Combat, "GuardEvent")       -- guard / hold block (legacy)
ensureRemoteEvent(Combat, "ClashEvent")       -- sword clash / deflect
ensureRemoteEvent(Combat, "SprintEvent")      -- sprint / dash
ensureRemoteEvent(Combat, "TargetLockEvent")  -- lock-on target
-- Dùng để Server gửi tín hiệu phát hiệu ứng (Máu, Tia lửa, Âm thanh) về cho Client
ensureRemoteEvent(Combat, "VFXEvent")
----------------------------------------------------------------
-- Interaction Remotes
----------------------------------------------------------------

-- ReplicatedStorage.Shared.Remotes.Interaction
local Interaction = ensureFolder(Remotes, "Interaction")

ensureRemoteEvent(Interaction, "InteractEvent")

----------------------------------------------------------------
-- Done
----------------------------------------------------------------

print("[RemoteBootstrap] All remotes are ready")
