-- d:\Game-roblox-Sekiro\src\server\Services\LegacyRemoteBridge.server.lua
-- LegacyRemoteBridge.server.lua
-- Forwards legacy ReplicatedStorage.Remotes events to the authoritative CombatService.
-- This ensures "NO DAMAGE" bugs are fixed even if legacy paths are used.
-- This file does NOT modify existing logic.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Services = ServerScriptService:WaitForChild("Services")

-- [FIX] DISABLE LEGACY BRIDGE
-- Prevents interception of Attack remote and conflicts with HitboxHandler
if true then
	return
end

local CombatService = require(Services:WaitForChild("CombatService"))
local PlayerStateService = require(Services:WaitForChild("PlayerStateService"))

-- Attempt to find the Legacy Remotes folder (non-blocking)
local LegacyRemotes = ReplicatedStorage:FindFirstChild("Remotes")

if LegacyRemotes then
    local Combat = LegacyRemotes:FindFirstChild("Combat")
    if Combat then
        local M1Event = Combat:FindFirstChild("M1Event")
        
        if M1Event then
            print("[LegacyRemoteBridge] Bridging legacy M1Event to CombatService")
            
            M1Event.OnServerEvent:Connect(function(player, payload)
                if not player or not player.Character then return end
                
                -- 1. Get Entities
                local attackerEntity = PlayerStateService.GetPlayerEntity(player)
                if not attackerEntity then return end
                
                local targetModel = payload and payload.target
                local targetEntity = nil
                
                -- 2. Auto-Targeting Fallback (if legacy payload lacks target)
                if targetModel then
                    targetEntity = PlayerStateService.GetEntityFromCharacter(targetModel)
                    if not targetEntity then
                        targetEntity = _G.NPC_ENTITIES and _G.NPC_ENTITIES[targetModel]
                    end
                else
                    -- Simple distance check for nearest enemy (Hotfix for legacy empty payloads)
                    local root = player.Character:FindFirstChild("HumanoidRootPart")
                    if root then
                        local closest, minDist = nil, 8
                        for _, entity in pairs(_G.NPC_ENTITIES or {}) do
                            if entity.RootPart and entity.State ~= "Dead" then
                                local dist = (entity.RootPart.Position - root.Position).Magnitude
                                if dist < minDist then
                                    minDist = dist
                                    closest = entity
                                end
                            end
                        end
                        targetEntity = closest
                    end
                end
                
                -- 3. Forward to Authoritative Service
                if targetEntity then
                    local weapon = (payload and payload.weapon) or { Name = "LegacyWeapon", Range = 6 }
                    CombatService.ProcessAttack(attackerEntity, targetEntity, weapon)
                end
            end)
        end
    end
else
    print("[LegacyRemoteBridge] No legacy remotes found (Clean state)")
end
