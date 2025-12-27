local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:FindFirstChild("Shared")
if not Shared then return end
local Remotes = Shared:FindFirstChild("Remotes")
if not Remotes then return end
local CombatRemotes = Remotes:FindFirstChild("Combat")
if not CombatRemotes then return end

local CombatService = require(script.Parent.CombatService)

local SprintRemote = CombatRemotes:FindFirstChild("SprintEvent")
if not SprintRemote then return end

SprintRemote.OnServerEvent:Connect(function(player, sprintData)
	if not player or not player:IsA("Player") then
		return
	end
	
	local character = player.Character
	if not character then
		return
	end
	
	sprintData = sprintData or {}
	local action = sprintData.action
	local playerState = sprintData.playerState
	
	if action == "start" then
		if CombatService.CanStartSprint(playerState) then
			character.SprintEnabled = true
		end
	elseif action == "stop" then
		character.SprintEnabled = false
	end
end)
