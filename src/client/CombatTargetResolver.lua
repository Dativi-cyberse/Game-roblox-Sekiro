-- d:\Game-roblox-Sekiro\src\client\CombatTargetResolver.lua
-- CombatTargetResolver.lua
-- Provides reliable spatial query logic to find valid combat targets.
-- This file does NOT modify existing logic.
-- This file is safe to remove.

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local CombatTargetResolver = {}

-- Configuration
local HITBOX_SIZE = Vector3.new(5, 6, 6) -- Width, Height, Depth
local HITBOX_OFFSET = CFrame.new(0, 0, -3.5) -- Forward offset from Root
local MAX_ANGLE = 0.5 -- Dot product threshold (~60 degrees)

local OVERLAP_PARAMS = OverlapParams.new()
OVERLAP_PARAMS.FilterType = Enum.RaycastFilterType.Exclude
OVERLAP_PARAMS.CollisionGroup = "Default"

-- Find the best target in front of the character
-- @param character Model
-- @param range number (optional)
-- @return Model | nil
function CombatTargetResolver.GetTarget(character, range)
    if not character then return nil end
    
    local root = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    range = range or 8

    -- Exclude self from query
    OVERLAP_PARAMS.FilterDescendantsInstances = { character }

    -- Create a hitbox in front of the player
    local hitboxCFrame = root.CFrame * HITBOX_OFFSET
    local parts = Workspace:GetPartBoundsInBox(hitboxCFrame, HITBOX_SIZE, OVERLAP_PARAMS)

    local bestTarget = nil
    local closestDist = range

    for _, part in ipairs(parts) do
        local model = part:FindFirstAncestorOfClass("Model")
        
        -- Basic validation: Not self, has Humanoid, Alive
        if model and model ~= character then
            local humanoid = model:FindFirstChild("Humanoid")
            local targetRoot = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")

            if humanoid and targetRoot and humanoid.Health > 0 then
                local toTarget = (targetRoot.Position - root.Position)
                local dist = toTarget.Magnitude
                
                -- Distance check
                if dist <= closestDist then
                    local dir = toTarget.Unit
                    local look = root.CFrame.LookVector
                    local dot = look:Dot(dir)

                    -- Angle check (must be in front)
                    if dot > MAX_ANGLE then
                        closestDist = dist
                        bestTarget = model
                    end
                end
            end
        end
    end

    return bestTarget
end

return CombatTargetResolver
