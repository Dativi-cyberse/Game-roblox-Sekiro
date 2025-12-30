-- d:\Game-roblox-Sekiro\src\client\TargetResolver.lua
-- TargetResolver.lua
-- Provides spatial query logic to find valid combat targets.
-- This file does NOT modify existing logic.
-- This file is safe to remove.

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local TargetResolver = {}

local DEFAULT_SIZE = Vector3.new(5, 6, 6) -- W, H, D
local DEFAULT_OFFSET = CFrame.new(0, 0, -3.5) -- Forward offset

-- Find the best target in front of the character
-- @param character Model
-- @param range number (optional)
-- @return Model | nil
function TargetResolver.GetTarget(character, range)
    if not character then return nil end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local overlapParams = OverlapParams.new()
    overlapParams.FilterDescendantsInstances = { character }
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    overlapParams.CollisionGroup = "Default"

    -- Create a hitbox in front of the player
    local cframe = root.CFrame * DEFAULT_OFFSET
    local parts = Workspace:GetPartBoundsInBox(cframe, DEFAULT_SIZE, overlapParams)

    local bestTarget = nil
    local minAngle = 0.5 -- Dot product threshold (~60 degrees)
    local minDist = range or 8

    for _, part in ipairs(parts) do
        local model = part:FindFirstAncestorOfClass("Model")
        if model and model ~= character then
            local humanoid = model:FindFirstChild("Humanoid")
            local targetRoot = model:FindFirstChild("HumanoidRootPart")

            if humanoid and targetRoot and humanoid.Health > 0 then
                local toTarget = (targetRoot.Position - root.Position)
                local dist = toTarget.Magnitude
                local dir = toTarget.Unit
                local facing = root.CFrame.LookVector
                local dot = facing:Dot(dir)

                -- Prioritize closest target within angle
                if dist < minDist and dot > minAngle then
                    minDist = dist
                    bestTarget = model
                end
            end
        end
    end

    return bestTarget
end

return TargetResolver
