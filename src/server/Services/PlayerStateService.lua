-- PlayerStateService.lua
-- Manages server-side PlayerEntity instances for combat testing.
-- Allows DummyEnemy to interact with Players using the CombatService API.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

-- Require the entity class (Assumes same folder)
local PlayerEntity = require(script.Parent.PlayerEntity)

local PlayerStateService = {}
local playerEntities = {} -- [Player] = PlayerEntity
local charEntities = {}   -- [Character] = PlayerEntity

-- API: Get Entity by Player
function PlayerStateService.GetPlayerEntity(player)
    return playerEntities[player]
end

-- API: Get Entity by Character (Useful for Hit Detection)
function PlayerStateService.GetEntityFromCharacter(character)
    return charEntities[character]
end

-- Internal: Create Entity
local function createEntity(player, character)
    if not character then return end
    
    -- Cleanup old mapping if exists
    if charEntities[character] then
        charEntities[character] = nil
    end

    local entity = PlayerEntity.new(player, character)
    playerEntities[player] = entity
    charEntities[character] = entity
    
    print("[PlayerStateService] Combat Entity created for " .. player.Name)
end

-- Internal: Remove Entity
local function removeEntity(player)
    local entity = playerEntities[player]
    if entity and entity.Character then
        charEntities[entity.Character] = nil
    end
    playerEntities[player] = nil
end

-- Lifecycle Connections
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        createEntity(player, character)
    end)
    
    if player.Character then
        createEntity(player, player.Character)
    end
end)

Players.PlayerRemoving:Connect(removeEntity)

-- Update Loop (Heartbeat)
RunService.Heartbeat:Connect(function(dt)
    for _, entity in pairs(playerEntities) do
        entity:Update(dt)
    end
end)

return PlayerStateService
