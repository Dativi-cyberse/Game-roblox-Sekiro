-- d:\Game-roblox-Sekiro\src\server\AI\SmartDummyController.server.lua
-- SmartDummyController.server.lua
-- Extends Dummy AI behavior by injecting high-priority intents (Guard/Retreat)
-- based on Posture and Stagger state.
-- This file does NOT modify existing AI files.

local RunService = game:GetService("RunService")

local function updateSmartAI()
    if not _G.NPC_ENTITIES then return end

    local now = os.clock()

    for model, entity in pairs(_G.NPC_ENTITIES) do
        if entity.State == "Dead" or entity._isDead then continue end

        -- 1. Stagger Handling
        -- If staggered, force intent to nil to prevent actions
        if entity._staggerUntil and entity._staggerUntil > now then
            entity.Intent = nil
            entity.State = "Staggered"
            continue
        end

        -- 2. Low Posture Survival
        -- If posture is critical (< 30%), force Guarding to recover
        if entity.Posture and entity.MaxPosture then
            local ratio = entity.Posture / entity.MaxPosture
            if ratio < 0.3 and entity.State ~= "Attacking" then
                -- Override Brain decision
                entity.Intent = "Guard"
            end
        end

        -- 3. Posture Broken State
        -- If posture is 0, ensure entity is vulnerable
        if entity.Posture <= 0 then
            entity._isGuardBroken = true
            entity.State = "Staggered"
            entity.Intent = nil
        end
    end
end

RunService.Heartbeat:Connect(updateSmartAI)

print("[SmartDummyController] AI Extension Running")
