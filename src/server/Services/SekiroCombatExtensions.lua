-- d:\Game-roblox-Sekiro\src\server\Services\SekiroCombatExtensions.lua
-- SekiroCombatExtensions.lua
-- Provides helper functions for Deathblow validation and Posture logic.
-- This file is optional and safe to integrate.

local SekiroCombatExtensions = {}

local DEATHBLOW_RANGE = 8
local DEATHBLOW_ANGLE = 0.5 -- Dot product

-- Advanced Deathblow Validation
function SekiroCombatExtensions.CanPerformDeathblow(attackerEntity, targetEntity)
    if not attackerEntity or not targetEntity then return false, "Invalid entities" end
    
    -- 1. Posture Check (Critical)
    local isBroken = false
    if targetEntity.Posture and targetEntity.Posture <= 0 then isBroken = true end
    if targetEntity._isGuardBroken then isBroken = true end
    if targetEntity._staggerUntil and targetEntity._staggerUntil > os.clock() then isBroken = true end
    
    if not isBroken then
        return false, "Target posture not broken"
    end

    -- 2. Distance Check
    local aRoot = attackerEntity.RootPart
    local tRoot = targetEntity.RootPart
    if not aRoot or not tRoot then return false, "No root part" end
    
    local dist = (aRoot.Position - tRoot.Position).Magnitude
    if dist > DEATHBLOW_RANGE then
        return false, "Too far"
    end

    -- 3. Orientation Check (Optional: Attacker facing target)
    local toTarget = (tRoot.Position - aRoot.Position).Unit
    local look = aRoot.CFrame.LookVector
    if look:Dot(toTarget) < DEATHBLOW_ANGLE then
        return false, "Not facing target"
    end

    return true, "Valid"
end

return SekiroCombatExtensions
