-- d:\Game-roblox-Sekiro\src\server\Services\SekiroParryHandler.server.lua
-- SekiroParryHandler.server.lua
-- Handles explicit Parry intent from the client.
-- Integrates ParryService with the Combat system.
-- This file is optional and safe to integrate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Services = ServerScriptService:WaitForChild("Services")

-- Attempt to locate ParryService (It is in src/server/ParryService.lua based on context)
local ParryService = require(ServerScriptService:WaitForChild("ParryService"))
local PlayerStateService = require(Services:WaitForChild("PlayerStateService"))
local CombatService = require(Services:WaitForChild("CombatService"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = Shared:WaitForChild("Remotes")
local CombatRemotes = Remotes:WaitForChild("Combat")

local ParryRemote = CombatRemotes:WaitForChild("Parry")

ParryRemote.OnServerEvent:Connect(function(player, payload)
    local entity = PlayerStateService.GetPlayerEntity(player)
    if not entity then return end

    -- Register Parry Intent
    -- This sets the timing window for incoming attacks to be parried
    local now = os.clock()
    entity.parryIntentTime = now
    entity.State = "Guarding"
    entity._isGuarding = true
    
    -- Optional: Check against specific incoming attack if the client provided one
    -- But usually, we just set the intent time, and ProcessAttack (when called by the attacker)
    -- checks this timestamp via GuardParry.ResolveParry.
    
    -- However, if we want to support "Reactionary" parries where the defender
    -- parries an attack that is ALREADY in flight (and tracked by ParryService):
    local result = ParryService.AttemptParry(entity, now)
    
    if result.success then
        -- If ParryService successfully resolved a pending attack:
        -- Apply effects that ParryService might have missed if it couldn't find CombatService
        if result.stagger and entity._incomingAttack then
            local attacker = entity._incomingAttack.attacker
            if attacker then
                CombatService.ApplyGuardDamage(attacker, 30) -- Bonus posture dmg
                attacker._staggerUntil = math.max(attacker._staggerUntil or 0, now + 0.5)
            end
        end
    end
end)

print("[SekiroParryHandler] Listening for Parry intent")
