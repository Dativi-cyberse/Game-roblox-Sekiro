-- RemotesSetup.server.lua
-- Ensures the RemoteEvent structure exists in ReplicatedStorage.Shared.Remotes
-- IMPORTANT: MUST NOT create ReplicatedStorage.Remotes

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- =========================
-- HELPERS
-- =========================

local function createFolder(parent, name)
	local f = parent:FindFirstChild(name)
	if f and f:IsA("Folder") then
		return f
	end
	f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function createRemote(parent, name)
	local r = parent:FindFirstChild(name)
	if r and r:IsA("RemoteEvent") then
		return r
	end
	r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = parent
	return r
end

-- =========================
-- SHARED ROOT (FIX)
-- =========================

-- ReplicatedStorage/Shared/Remotes ONLY
local Shared = createFolder(ReplicatedStorage, "Shared")
local Remotes = createFolder(Shared, "Remotes")

-- =========================
-- COMBAT REMOTES
-- =========================

local combatFolder = createFolder(Remotes, "Combat")

-- Legacy combat remotes (kept for compatibility)
createRemote(combatFolder, "M1Event")
createRemote(combatFolder, "GuardEvent")
createRemote(combatFolder, "SprintEvent")
createRemote(combatFolder, "ClashEvent")
createRemote(combatFolder, "TargetLockEvent")

-- New combat remotes
createRemote(combatFolder, "Attack")
createRemote(combatFolder, "Parry")
createRemote(combatFolder, "Block")
createRemote(combatFolder, "Deathblow")

-- =========================
-- INTERACTION REMOTES
-- =========================

local interactFolder = createFolder(Remotes, "Interaction")
createRemote(interactFolder, "InteractEvent")

print("[RemotesSetup] Remotes ensured in ReplicatedStorage.Shared.Remotes")
