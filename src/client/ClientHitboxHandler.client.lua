-- d:\Game-roblox-Sekiro\src\client\ClientHitboxHandler.client.lua
-- ClientHitboxHandler.client.lua
-- DISABLED: Redundant adapter. Use CombatHitHandler.client.lua instead.
-- This file does NOT modify existing logic.
-- This file is safe to remove without breaking the game.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = Shared:WaitForChild("Remotes")
local CombatRemotes = Remotes:WaitForChild("Combat")
local AttackRemote = CombatRemotes:WaitForChild("Attack")

local Player = Players.LocalPlayer

-- =========================
-- DISABLED FLAG
-- =========================
local DISABLED = true
if DISABLED then
	return
end

-- Configuration
local HITBOX_SIZE = Vector3.new(5, 5, 6)
local HITBOX_OFFSET = CFrame.new(0, 0, -3)
local DEFAULT_WEAPON = {
	Name = "Katana",
	Range = 6,
}

local function findTarget(char)
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterDescendantsInstances = { char }
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.CollisionGroup = "Default"

	local cframe = root.CFrame * HITBOX_OFFSET
	local parts = Workspace:GetPartBoundsInBox(cframe, HITBOX_SIZE, overlapParams)

	local closestTarget
	local minDist = math.huge

	for _, part in ipairs(parts) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and model ~= char then
			local humanoid = model:FindFirstChild("Humanoid")
			local targetRoot = model:FindFirstChild("HumanoidRootPart")

			if humanoid and targetRoot and humanoid.Health > 0 then
				local dist = (targetRoot.Position - root.Position).Magnitude
				if dist < minDist then
					minDist = dist
					closestTarget = model
				end
			end
		end
	end

	return closestTarget
end

local function onAnimationPlayed(track)
	track:GetMarkerReachedSignal("Hit"):Connect(function()
		local char = Player.Character
		if not char then return end

		local target = findTarget(char)
		if target then
			AttackRemote:FireServer({
				target = target,
				weapon = DEFAULT_WEAPON,
			})
		end
	end)
end

local function onCharacterAdded(newChar)
	local animator = newChar:WaitForChild("Humanoid"):WaitForChild("Animator")
	animator.AnimationPlayed:Connect(onAnimationPlayed)
end

if Player.Character then
	onCharacterAdded(Player.Character)
end

Player.CharacterAdded:Connect(onCharacterAdded)
