-- d:\Game-roblox-Sekiro\src\server\AI\DummyEnemy.lua
-- DummyEnemy.lua
-- NPC AI Class
-- Encapsulates FSM, Context, and Decision Logic for a single NPC.
-- Driven externally by DummyBrain.server.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local Services = ServerScriptService:WaitForChild("Services")
local CombatService = require(Services:WaitForChild("CombatService"))

-- FSM Modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local FSMFolder = Shared:WaitForChild("Modules"):WaitForChild("FSM")

local StateMachine = require(FSMFolder:WaitForChild("StateMachine"))
local IdleState = require(FSMFolder:WaitForChild("IdleState"))
local AttackState = require(FSMFolder:WaitForChild("AttackState"))
local BlockState = require(FSMFolder:WaitForChild("BlockState"))
local MoveState = require(FSMFolder:WaitForChild("MoveState"))
local ParryState = require(FSMFolder:WaitForChild("ParryState"))
local HitStunState = require(FSMFolder:WaitForChild("HitStunState"))
local DeathState = require(FSMFolder:WaitForChild("DeathState"))

-- AI Logic
local DummyBrain = require(script.Parent:WaitForChild("DummyBrain"))

-- Client-side logic adapted for Server
local AnimationController = require(game.StarterPlayer.StarterCharacterScripts.AnimationController)

-- =====================================================
-- NPC CONTROLLERS (Server Mocks)
-- =====================================================

local NPCCombatController = {}
NPCCombatController.__index = NPCCombatController

function NPCCombatController.new(entity, context)
	local self = setmetatable({}, NPCCombatController)
	self.entity = entity
	self.context = context
	return self
end

function NPCCombatController:StartParry()
	self.entity.parryIntentTime = os.clock()
	self.entity.State = "Guarding"
	self.entity._isGuarding = true
end

function NPCCombatController:StopParry()
	self.entity.State = "Idle"
	self.entity._isGuarding = false
end

function NPCCombatController:IsParryExpired()
	return (os.clock() - self.entity.parryIntentTime) > 0.25
end

function NPCCombatController:StartHitStun()
	self.entity.State = "Staggered"
	self.hitStunEnd = os.clock() + 0.5
end

function NPCCombatController:StopHitStun()
	self.entity.State = "Idle"
end

function NPCCombatController:IsHitStunFinished()
	return os.clock() >= self.hitStunEnd
end

local NPCDashController = {}
NPCDashController.__index = NPCDashController
function NPCDashController.new() return setmetatable({}, NPCDashController) end
function NPCDashController:Dash(dir) end -- No physics dash for simple NPC yet

-- =====================================================
-- NPC CLASS
-- =====================================================

local DummyEnemy = {}
DummyEnemy.__index = DummyEnemy

function DummyEnemy.new(model)
	local self = setmetatable({}, DummyEnemy)
	
	self.model = model
	self.humanoid = model:WaitForChild("Humanoid")
	self.animator = self.humanoid:WaitForChild("Animator")
	self.root = model:WaitForChild("HumanoidRootPart")
	
	self.brain = DummyBrain.new()
	self.AI_TICK = 0.1
	self.lastThink = 0
	self.attackCooldown = 2 -- [MUGEN FIX] Cooldown between attack chains
	self.targetEntity = nil -- [MUGEN] Persistent Target Lock
	
	-- 2. Register Entity
	if not model:GetAttribute("EntityId") then
		model:SetAttribute("EntityId", game:GetService("HttpService"):GenerateGUID(false))
	end
	
	local entity = _G.GetCombatEntity and _G.GetCombatEntity(model)
	if not entity then
		-- Fallback registration if NpcRegistry is slow
		entity = {
			EntityType = "NPC",
			IsNPC = true,
			Model = model,
			RootPart = self.root,
			Humanoid = self.humanoid,
			Health = 100,
			MaxHealth = 100,
			Team = "Enemy",
			State = "Idle",
			_lastAttackIntentTime = 0
		}
		_G.NPC_ENTITIES = _G.NPC_ENTITIES or {}
		_G.NPC_ENTITIES[model] = entity
	end
	self.entity = entity
	
	-- 3. Setup Context & FSM
	local animController = AnimationController.new(self.animator)
	
	self.context = {
		Humanoid = self.humanoid,
		Animator = self.animator,
		Root = self.root,
		AnimationController = animController,
		
		isNPC = true, -- [FIX] Add Identity Flag
		isPlayer = false,
		parryRequested = false,
		moveTarget = nil,
		lastAttackTime = 0, -- [MUGEN FIX] Track last attack time
		currentTargetEntity = nil, -- [MUGEN] Shared with FSM
		
		weaponEquipped = true, -- Always armed
		comboIndex = 1,
		comboQueued = false,
		sprintRequested = false,
		attackRequested = false,
		blockRequested = false,
		
		Controllers = {
			DashController = NPCDashController.new()
		}
	}
	
	-- Mock CombatController
	self.context.Controllers.CombatController = NPCCombatController.new(self.entity, self.context)
	
	-- Initialize States
	self.context.States = {
		Idle   = IdleState.new(),
		Attack = AttackState.new(),
		Block  = BlockState.new(),
		Move   = MoveState.new(),
		Dash   = nil, -- Not using DashState for simple AI
		Parry  = ParryState.new(),
		HitStun = HitStunState.new(),
		Death  = DeathState.new(),
	}
	
	self.fsm = StateMachine.new(self.context.States.Idle, self.context)
	self.context.StateMachine = self.fsm
	
	return self
end

function DummyEnemy:Update(dt)
	-- [FIX] Disable AI if dead
	if self.entity.State == "Dead" or self.entity.Health <= 0 then
		return
	end

	if self.entity.Health <= 0 then
		if self.fsm:GetState().name ~= "Death" then
			self.fsm:ChangeState(self.context.States.Death)
		end
		return
	end
	
	-- 1. Update FSM
	self.fsm:Update(dt)
	
	-- 2. Sync FSM State TO Entity (Crucial for Brain/CombatService)
	self.entity.State = self.fsm:GetState().name
	
	-- Debug FSM State
	-- print("[DummyEnemy] Current State:", self.entity.State)

	-- 3. Sync External State FROM Entity (e.g. Stagger from CombatService)
	if self.entity.State == "Staggered" and self.fsm:GetState().name ~= "HitStun" then
		self.fsm:ChangeState(self.context.States.HitStun)
	end
	
	-- 4. AI Decision Making
	if os.clock() - self.lastThink > self.AI_TICK then
		self.lastThink = os.clock()
		self:_Think(dt)
	end
end

function DummyEnemy:_Think(dt)
	local ATTACK_RANGE = 6    -- [MUGEN FIX] Strict attack range
	local AGGRO_RANGE = 14    -- [MUGEN FIX] Chase range
	local DISENGAGE_RANGE = 25 -- [MUGEN FIX] Leash range

	-- 1. Target Acquisition / Maintenance
	if not self.targetEntity or not self.targetEntity.RootPart or self.targetEntity.Health <= 0 then
		self.targetEntity = nil
		self.context.currentTargetEntity = nil
		
		-- Scan for new target
		local minDist = AGGRO_RANGE
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
				local dist = (p.Character.HumanoidRootPart.Position - self.root.Position).Magnitude
				if dist < minDist then
					minDist = dist
					local pEntity = _G.GetCombatEntityById and _G.GetCombatEntityById(p.UserId) 
						or require(Services.PlayerStateService).GetPlayerEntity(p)
					if pEntity and pEntity.Health > 0 then
						self.targetEntity = pEntity
					end
				end
			end
		end
	else
		-- Check Disengage
		local dist = (self.targetEntity.RootPart.Position - self.root.Position).Magnitude
		if dist > DISENGAGE_RANGE then
			self.targetEntity = nil
			self.context.currentTargetEntity = nil
		end
	end
	
	-- Reset Inputs (Default to false unless Brain says otherwise)
	self.context.attackRequested = false
	self.context.blockRequested = false
	self.context.parryRequested = false
	self.context.moveTarget = nil
	
	local now = os.clock()

	if self.targetEntity then
		self.context.currentTargetEntity = self.targetEntity
		-- Ask Brain for Intent
		local intent = self.brain:Decide(self.entity, self.targetEntity, dt)
		
		-- [MUGEN FIX] Cooldown Check
		local onCooldown = (now - self.context.lastAttackTime) < self.attackCooldown
		
		if intent == "Attack" then
			print("[DummyEnemy] Intent: ATTACK")
			self.context.attackRequested = true
			self.entity._lastAttackTime = os.clock() -- [FIX] Update cooldown timer
			
			-- Combo Logic: If already attacking, queue next
			if self.fsm:GetState().name == "Attack" then
				-- print("[DummyEnemy] Queueing Combo M1")
				self.fsm:HandleInput("M1")
			elseif not onCooldown then
				-- Only start new chain if off cooldown
				self.context.attackRequested = true
				self.context.lastAttackTime = now
			end
			
		elseif intent == "Guard" then
			print("[DummyEnemy] Intent: GUARD")
			self.context.blockRequested = true
			
		elseif intent == "Parry" then
			print("[DummyEnemy] Intent: PARRY")
			self.context.parryRequested = true
			
		else
			-- No Combat Intent -> Handle Movement
			local dist = (self.targetEntity.RootPart.Position - self.root.Position).Magnitude
			
			-- [FIX] Only chase if within Aggro Range and outside Attack Range
			if dist > ATTACK_RANGE and dist < AGGRO_RANGE then
				self.context.moveTarget = self.targetEntity.RootPart.Position
			elseif dist >= AGGRO_RANGE then
				self.context.moveTarget = nil -- Stop chasing if too far
			end
		end
	end
end

return DummyEnemy
