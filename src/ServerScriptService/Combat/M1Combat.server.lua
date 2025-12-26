-- M1Combat.server.lua
-- Server script placed under ServerScriptService/Combat
-- Receives marker-triggered RemoteEvent calls from clients and performs server-side
-- validation, creates a short-lived hitbox in front of the attacker, and applies
-- damage to valid targets. All damage calculations happen server-side.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local combatRemotes = remotes:WaitForChild("Combat")
local m1Remote = combatRemotes:WaitForChild("M1Event")

-- Configuration (server authoritative)
local SERVER_COOLDOWN = 0.25 -- prevent clients from firing too frequently
local HITBOX_SIZE = Vector3.new(3, 3, 4) -- width, height, depth of the box in front
local HITBOX_OFFSET_FORWARD = 2.5 -- how far in front of root to center the box
local HITBOX_DURATION = 0.12 -- seconds before the temporary hitbox is removed
local DAMAGE_PER_HIT = {10, 12, 18} -- damage for Slash1, Slash2, Slash3 (server-side)

-- State
local lastProcessed = {} -- player -> last processed attack time

-- Defensive helper: get the tool the player is actually holding
local function getEquippedTool(character)
	for _, v in ipairs(character:GetChildren()) do
		if v:IsA("Tool") then
			return v
		end
	end
	return nil
end

-- Main handler
m1Remote.OnServerEvent:Connect(function(player, comboIndexFromClient)
	-- Validate player
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	local now = os.clock()
	local last = lastProcessed[player]
	if last and now - last < SERVER_COOLDOWN then
		-- Too soon; ignore to prevent abuse
		return
	end

	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
	if not humanoid or not root then return end
	if humanoid.Health <= 0 then return end

	-- Validate tool is equipped (basic check)
	local tool = getEquippedTool(character)
	if not tool then
		return
	end

	-- Clamp combo index and pick server-side damage
	local comboIdx = tonumber(comboIndexFromClient) or 1
	comboIdx = math.clamp(math.floor(comboIdx), 1, #DAMAGE_PER_HIT)
	local damage = DAMAGE_PER_HIT[comboIdx] or DAMAGE_PER_HIT[1]

	-- Record processed time to enforce server cooldown
	lastProcessed[player] = now

	-- Compute hitbox center in front of the player
	local forward = root.CFrame.LookVector
	local centerPos = root.Position + forward * HITBOX_OFFSET_FORWARD
	local boxCFrame = CFrame.new(centerPos, centerPos + forward)

	-- Create a visible/ghost hitbox for debugging (transparent, non-colliding)
	local hitbox = Instance.new("Part")
	hitbox.Name = "M1_Hitbox"
	hitbox.Size = HITBOX_SIZE
	hitbox.CFrame = boxCFrame
	hitbox.Transparency = 1
	hitbox.CanCollide = false
	hitbox.Anchored = true
	hitbox.Parent = Workspace
	Debris:AddItem(hitbox, HITBOX_DURATION)

	-- Use overlap parameters to ignore the attacker's character
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = {character}

	-- Query parts in box
	local parts = Workspace:GetPartBoundsInBox(boxCFrame, HITBOX_SIZE, params)

	-- Track which humanoids we've damaged this swing to avoid double-damage
	local damagedHumanoids = {}

	for _, part in ipairs(parts) do
		local hitChar = part:FindFirstAncestorOfClass("Model")
		if hitChar and hitChar ~= character then
			local hitHum = hitChar:FindFirstChildOfClass("Humanoid")
			if hitHum and hitHum.Health > 0 and not damagedHumanoids[hitHum] then
				-- Apply damage server-side
				hitHum:TakeDamage(damage)
				damagedHumanoids[hitHum] = true
			end
		end
	end
end)

print("M1Combat.server.lua loaded — server will process M1 hit markers")
