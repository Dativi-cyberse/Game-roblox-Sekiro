local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local TargetLockService = {}
local locks = {}

local CombatRemotes = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Combat")
local LockEvent = CombatRemotes and CombatRemotes:FindFirstChild("TargetLockEvent")

local function validTarget(player, target)
    if not target or not target.Parent then return false end
    local hrp = target:FindFirstChild("HumanoidRootPart")
    if not hrp or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return false end
    local dist = (hrp.Position - player.Character.HumanoidRootPart.Position).Magnitude
    return dist <= 30
end

if LockEvent then
    LockEvent.OnServerEvent:Connect(function(player, action, target)
        if action == "lock" and target then
            if validTarget(player, target) then
                locks[player] = target
                LockEvent:FireClient(player, "locked", target)
            end
        elseif action == "unlock" then
            locks[player] = nil
            LockEvent:FireClient(player, "unlocked")
        end
    end)
end

return TargetLockService
