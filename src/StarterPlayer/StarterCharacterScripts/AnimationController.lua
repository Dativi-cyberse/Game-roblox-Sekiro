-- AnimationController.lua
-- Client-side animation manager for R15 combat system

local AnimationController = {}
AnimationController.__index = AnimationController

-- =====================================================
-- ANIMATION IDS
-- =====================================================

local ANIMATION_IDS = {
	Idle   = "117428425939221",
	Sprint = "125710871592563",
	Guard  = "110454192036754",
	
	RDash  = "133650397070060",
	LDash  = "72307653613351",
	FDash1 = "115223618743226",
	FDash2 = "108189754217336",
	BDash  = "81293025442865",

	Slash1 = "107432081428264",
	Slash2 = "75814337439061",
	Slash3 = "116183119194533",
	Slash4 = "107471212849510",
}

-- =====================================================
-- CONSTRUCTOR
-- =====================================================

function AnimationController.new(animator)
	local self = setmetatable({}, AnimationController)

	self.animator = animator

	-- [MUGEN SAFE CHANGE]
	self.currentBaseTrack = nil
	self.currentAttackTrack = nil
	self.attackStoppedConnection = nil

	self.animationRegistry = {}
	self.markerConnections = {}

	self.animationPlayedSignal = Instance.new("BindableEvent")
	self.animationEndedSignal = Instance.new("BindableEvent")

	self._forwardDashIndex = 1

	self:_LoadAnimations()
	return self
end

-- =====================================================
-- LOAD ANIMATIONS
-- =====================================================

function AnimationController:_LoadAnimations()
	if not self.animator then
		warn("[AnimationController] No Animator")
		return
	end

	for name, id in pairs(ANIMATION_IDS) do
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://" .. id

		local success, track = pcall(function()
			return self.animator:LoadAnimation(anim)
		end)

		if success and track then
			if name == "Idle" then
				track.Priority = Enum.AnimationPriority.Idle
			elseif name == "Sprint" then
				track.Priority = Enum.AnimationPriority.Movement
			else
				track.Priority = Enum.AnimationPriority.Action
			end

			track.Looped = (name == "Idle" or name == "Guard" or name == "Sprint")
			self.animationRegistry[name] = track
		end
	end
end

-- =====================================================
-- BASIC STATES
-- =====================================================

function AnimationController:PlayIdle()
	return self:_PlayBase("Idle", 0.2)
end

function AnimationController:PlaySprint()
	return self:_PlayBase("Sprint", 0.15)
end

function AnimationController:PlayGuard()
	return self:_PlayBase("Guard", 0.1)
end

-- =====================================================
-- DASH
-- =====================================================

function AnimationController:PlayDash(direction)
	local forward = Vector3.new(0, 0, -1)
	local right   = Vector3.new(1, 0, 0)

	local fDot = direction and direction:Dot(forward) or 1
	local rDot = direction and direction:Dot(right) or 0

	local dashName
	if fDot > 0.6 then
		dashName = (self._forwardDashIndex == 1) and "FDash1" or "FDash2"
		self._forwardDashIndex = (self._forwardDashIndex == 1) and 2 or 1
	elseif fDot < -0.6 then
		dashName = "BDash"
	elseif rDot > 0 then
		dashName = "RDash"
	else
		dashName = "LDash"
	end

	return self:_PlayBase(dashName, 0.05)
end

-- =====================================================
-- ATTACK
-- =====================================================

function AnimationController:PlaySlash(index)
	return self:_PlayAttack("Slash" .. index, 0.05)
end

-- =====================================================
-- CORE PLAY LOGIC
-- =====================================================

-- [MUGEN SAFE CHANGE] Base animations (Idle / Sprint / Dash)
function AnimationController:_PlayBase(slotName, fadeTime)
	local track = self.animationRegistry[slotName]
	if not track then return end

	if self.currentBaseTrack and self.currentBaseTrack ~= track then
		self.currentBaseTrack:Stop(fadeTime)
	end

	track:Play(fadeTime)
	self.currentBaseTrack = track

	self.animationPlayedSignal:Fire(slotName, track)
	return track
end

-- [MUGEN SAFE CHANGE] Attack animations (Slash 1–4)
function AnimationController:_PlayAttack(slotName, fadeTime)
	local track = self.animationRegistry[slotName]
	if not track then
		warn("[AnimationController] Missing attack animation:", slotName)
		return
	end

	-- [FIX] Clean up previous connection FIRST to prevent leaks
	if self.attackStoppedConnection then
		self.attackStoppedConnection:Disconnect()
		self.attackStoppedConnection = nil
	end

	-- [FIX] Always stop current attack to ensure clean restart (even if same track)
	if self.currentAttackTrack then
		self.currentAttackTrack:Stop(fadeTime)
		self.currentAttackTrack = nil
	end

	track:Play(fadeTime)
	self.currentAttackTrack = track

	self:_ConnectMarkers(track, slotName)
	self.animationPlayedSignal:Fire(slotName, track)

	self.attackStoppedConnection = track.Stopped:Connect(function()
		if self.currentAttackTrack == track then
			self.currentAttackTrack = nil
		end
		self.animationEndedSignal:Fire(slotName)
	end)

	return track
end

-- =====================================================
-- MARKERS
-- =====================================================

function AnimationController:_ConnectMarkers(track, slotName)
	if self.markerConnections[slotName] then
		for _, c in ipairs(self.markerConnections[slotName]) do
			pcall(function() c:Disconnect() end)
		end
	end

	self.markerConnections[slotName] = {}

	for _, markerName in ipairs({ "Hit", "ParryWindow", "ComboAllow" }) do
		local ok, signal = pcall(function()
			return track:GetMarkerReachedSignal(markerName)
		end)
		if ok and signal then
			table.insert(self.markerConnections[slotName], signal:Connect(function() end))
		end
	end
end

-- =====================================================
-- UTIL
-- =====================================================

function AnimationController:Reset()
	if self.currentAttackTrack then
		self.currentAttackTrack:Stop(0)
		self.currentAttackTrack = nil
	end
	if self.attackStoppedConnection then
		self.attackStoppedConnection:Disconnect()
		self.attackStoppedConnection = nil
	end
	if self.currentBaseTrack then
		self.currentBaseTrack:Stop(0)
		self.currentBaseTrack = nil
	end
end
-- [MUGEN SAFE CHANGE] Compatibility stub
-- CombatClient vẫn gọi StopAll(), nên cần giữ hàm này
function AnimationController:StopAll(except, fadeTime)
	fadeTime = fadeTime or 0.1

	if self.currentAttackTrack then
		self.currentAttackTrack:Stop(fadeTime)
		self.currentAttackTrack = nil
	end

	-- [FIX] Ensure connection is cleaned up
	if self.attackStoppedConnection then
		self.attackStoppedConnection:Disconnect()
		self.attackStoppedConnection = nil
	end

	if self.currentBaseTrack then
		self.currentBaseTrack:Stop(fadeTime)
		self.currentBaseTrack = nil
	end
end
-- ===============================
-- MUGEN FSM COMPATIBILITY
-- ===============================

function AnimationController:PlayAttack(comboIndex)
	return self:PlaySlash(comboIndex)
end

function AnimationController:PlayMove()
	return self:PlaySprint()
end

return AnimationController
