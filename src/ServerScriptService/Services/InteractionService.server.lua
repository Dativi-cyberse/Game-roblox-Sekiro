local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local interaction = remotes:WaitForChild("Interaction")
local InteractEvent = interaction:FindFirstChild("InteractEvent")

local InteractionService = {}

if InteractEvent then
    -- Placeholder listener: validate and accept requests; detailed logic implemented later
    InteractEvent.OnServerEvent:Connect(function(player, payload)
        -- payload expected: { target = Instance, action = "interact" }
        if not player or not payload then return end
        -- minimal validation (distance and basic shape)
        -- concrete interaction logic will be implemented in InteractionService when needed
        print("[InteractionService] Received interact from", player.Name)
    end)
end

return InteractionService
