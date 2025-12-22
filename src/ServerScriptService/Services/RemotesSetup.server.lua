-- RemotesSetup.server.lua
-- Ensures the RemoteEvent structure exists in ReplicatedStorage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function createFolder(parent, name)
    local f = parent:FindFirstChild(name)
    if f and f:IsA("Folder") then return f end
    f = Instance.new("Folder")
    f.Name = name
    f.Parent = parent
    return f
end

local function createRemote(parent, name)
    local r = parent:FindFirstChild(name)
    if r and r:IsA("RemoteEvent") then return r end
    r = Instance.new("RemoteEvent")
    r.Name = name
    r.Parent = parent
    return r
end

-- Top-level Remotes folder
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
    remotes = Instance.new("Folder")
    remotes.Name = "Remotes"
    remotes.Parent = ReplicatedStorage
end

-- Combat remotes
local combatFolder = createFolder(remotes, "Combat")
createRemote(combatFolder, "M1Event")
createRemote(combatFolder, "GuardEvent")
createRemote(combatFolder, "SprintEvent")
createRemote(combatFolder, "ClashEvent")
createRemote(combatFolder, "TargetLockEvent")

-- Interaction remotes
local interactFolder = createFolder(remotes, "Interaction")
createRemote(interactFolder, "InteractEvent")

print("[RemotesSetup] Remotes ensured in ReplicatedStorage")
