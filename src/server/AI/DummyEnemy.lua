-- DummyEnemy.lua
-- Controls Dummy AI behavior (Brain + FSM)
-- IMPORTANT:
-- - Does NOT create DummyEntity
-- - Does NOT update entity lifecycle
-- - Attacks ONLY when ENTERING Attack state
-- - No dependency on player attack timing

local ServerScriptService = game:GetService("ServerScriptService")
local AI = ServerScriptService:WaitForChild("AI")
local Services = ServerScriptService:WaitForChild("Services")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DummyFSM = require(AI:WaitForChild("DummyFSM"))
local DummyBrain = require(AI:WaitForChild("DummyBrain"))

local CombatService = require(Services:WaitForChild("CombatService"))
local PlayerStateService = require(Services:WaitForChild("PlayerStateService"))

local DummyEnemy = {}

function DummyEnemy.Start()

	-- =========================
	-- CONFIG
	-- =========================
	local DUMMY_WEAPON = {
		Name = "TrainingSword",
		BaseDamage = 5,
		BasePostureDamage = 10,
		Range = 6,
	}

	-- =========================
	-- FIND MODEL
	-- =========================
	local model = workspace:FindFirstChild("SekiroDummy")
	if not model then
		warn("[DummyEnemy] SekiroDummy model not found")
		return
	end

	-- =========================
	-- GET EXISTING ENTITY (CRITICAL)
	-- =========================
	if not _G.NPC_ENTITIES then
		warn("[DummyEnemy] Global NPC registry not found")
		return
	end

	local entity = _G.NPC_ENTITIES[model]
	if not entity then
		warn("[DummyEnemy] Entity not registered for model:", model.Name)
		return
	end

	-- =========================
	-- AI CORE
	-- =========================
	local fsm = DummyFSM.new(entity)
	local brain = DummyBrain.new()

	-- =========================
	-- TARGETING
	-- =========================
	local function findNearestPlayer()
		local closestPlayer = nil
		local minDistance = math.huge

		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			if char and char:FindFirstChild("HumanoidRootPart") then
				local dist = (char.HumanoidRootPart.Position - entity.RootPart.Position).Magnitude
				if dist < minDistance then
					minDistance = dist
					closestPlayer = player
				end
			end
		end

		return closestPlayer
	end

	-- =========================
	-- STATE TRACKING
	-- =========================
	local lastStateName = ""

	-- =========================
	-- MAIN LOOP
	-- =========================
	RunService.Heartbeat:Connect(function(dt)

		-- 1. Acquire target
		local targetPlayer = findNearestPlayer()
		if not targetPlayer then
			return
		end

		local playerEntity = PlayerStateService.GetPlayerEntity(targetPlayer)
		if not playerEntity then
			return
		end

		-- 2. Brain decides intent ONLY
		entity.Intent = brain:Decide(entity, playerEntity, dt)

		-- 3. FSM executes state logic
		fsm:Update(dt)

		local currentStateName = fsm:GetCurrentState()

		-- 4. ATTACK: trigger damage ONLY on ENTER Attack
		if currentStateName == "Attack" and lastStateName ~= "Attack" then
			CombatService.ProcessAttack(entity, playerEntity, DUMMY_WEAPON)
		end

		-- 5. Update state memory
		lastStateName = currentStateName
	end)
end

return DummyEnemy
