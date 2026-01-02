-- d:\Game-roblox-Sekiro\src\server\AI\SmartDummyController.server.lua
-- SmartDummyController.server.lua
-- MAIN AI DRIVER
-- Instantiates DummyEnemy wrappers and drives their FSM Update loop.

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local AI = ServerScriptService:WaitForChild("AI")
local DummyEnemy = require(AI:WaitForChild("DummyEnemy"))

local activeNPCs = {} -- [Model] = DummyEnemyInstance

-- =====================================================
-- NPC MANAGEMENT
-- =====================================================

local function onNpcAdded(model)
	if activeNPCs[model] then return end
	
	-- Simple check for valid NPC candidates
	if model:IsA("Model") and (string.find(model.Name, "Dummy") or string.find(model.Name, "Sekiro")) then
		local humanoid = model:FindFirstChild("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		
		if humanoid and root then
			print("[SmartDummyController] Attaching AI to:", model.Name)
			activeNPCs[model] = DummyEnemy.new(model)
		end
	end
end

local function onNpcRemoved(model)
	if activeNPCs[model] then
		print("[SmartDummyController] Detaching AI from:", model.Name)
		activeNPCs[model] = nil
	end
end

-- 1. Scan existing
for _, child in ipairs(Workspace:GetChildren()) do
	onNpcAdded(child)
end

-- 2. Listen for new
Workspace.ChildAdded:Connect(onNpcAdded)
Workspace.ChildRemoved:Connect(onNpcRemoved)

RunService.Heartbeat:Connect(function(dt)
	for model, npc in pairs(activeNPCs) do
		if model.Parent then
			npc:Update(dt)
		else
			activeNPCs[model] = nil
		end
	end
end)

print("[SmartDummyController] AI Driver Running")
