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
	self.currentTrack = nil
	self.animationRegistry = {}
	self.markerConnections = {}

	self.animationPlayedSignal = Instance.new("BindableEvent")
	self.animationEndedSignal = Instance.new("BindableEvent")

	-- 🔥 FORWARD DASH ORDER (FDash1 -> FDash2 -> repeat)
	self._forwardDashIndex = 1

	self:_LoadAnimations()
	return self
end

-- =====================================================
-- LOAD ANIMATIONS (ONCE)
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
			-- Priority
			if name == "Idle" then
				track.Priority = Enum.AnimationPriority.Idle
			elseif name == "Sprint" then
				track.Priority = Enum.AnimationPriority.Movement
			else
				track.Priority = Enum.AnimationPriority.Action
			end

			track.Looped = (name == "Idle" or name == "Guard" or name == "Sprint")
			self.animationRegistry[name] = track
		else
			warn("[AnimationController] Failed to load animation:", name)
		end
	end

	local count = 0
	for _ in pairs(self.animationRegistry) do count += 1 end
	print("[AnimationController] Loaded", count, "animations")
end

-- =====================================================
-- BASIC STATES
-- =====================================================

function AnimationController:PlayIdle()
	return self:_PlayAnimation("Idle", 0.2)
end

function AnimationController:PlaySprint()
	return self:_PlayAnimation("Sprint", 0.15)
end

function AnimationController:PlayGuard()
	return self:_PlayAnimation("Guard", 0.1)
end

-- =====================================================
-- DASH (ORDERED, NOT RANDOM)
-- =====================================================

function AnimationController:PlayDash(direction)
	-- direction: Vector3 in LOCAL SPACE

	local forward = Vector3.new(0, 0, -1)
	local right   = Vector3.new(1, 0, 0)

	local fDot = direction and direction:Dot(forward) or 1
	local rDot = direction and direction:Dot(right) or 0

	-- ===== FORWARD DASH (FDash1 -> FDash2) =====
	if fDot > 0.6 then
		local dashName
		if self._forwardDashIndex == 1 then
			dashName = "FDash1"
			self._forwardDashIndex = 2
		else
			dashName = "FDash2"
			self._forwardDashIndex = 1
		end

		local track = self:_PlayAnimation(dashName, 0.05)
		if track then
			track:AdjustSpeed(0.5) -- kéo dài animation
		end
		return track
	end

	-- ===== BACK DASH =====
	if fDot < -0.6 then
		self._forwardDashIndex = 1
		local track = self:_PlayAnimation("BDash", 0.05)
		if track then track:AdjustSpeed(0.5) end
		return track
	end

	-- ===== RIGHT DASH =====
	if rDot > 0 then
		self._forwardDashIndex = 1
		local track = self:_PlayAnimation("RDash", 0.05)
		if track then track:AdjustSpeed(0.5) end
		return track
	end

	-- ===== LEFT DASH =====
	self._forwardDashIndex = 1
	local track = self:_PlayAnimation("LDash", 0.05)
	if track then track:AdjustSpeed(0.5) end
	return track
end

function AnimationController:StopDash()
	self:StopAll(nil, 0.05)
end

-- =====================================================
-- ATTACK
-- =====================================================

function AnimationController:PlaySlash(index)
	return self:_PlayAnimation("Slash" .. index, 0.1)
end

function AnimationController:PlayAttack()
	return self:PlaySlash(1)
end

-- =====================================================
-- CORE PLAY LOGIC
-- =====================================================

function AnimationController:_PlayAnimation(slotName, fadeTime)
	fadeTime = fadeTime or 0.1
	local track = self.animationRegistry[slotName]
	if not track then
		warn("[AnimationController] Missing animation:", slotName)
		return nil
	end

	if self.currentTrack and self.currentTrack ~= track then
		self.currentTrack:Stop(fadeTime)
	end

	track:Play(fadeTime)
	self.currentTrack = track

	self:_ConnectMarkers(track, slotName)
	self.animationPlayedSignal:Fire(slotName, track)

	if not track.Looped then
		local conn
		conn = track.Stopped:Connect(function()
			if self.currentTrack == track then
				self.currentTrack = nil
			end
			self.animationEndedSignal:Fire(slotName)
			if conn then conn:Disconnect() end
		end)
	end

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

function AnimationController:StopAll(except, fadeTime)
	fadeTime = fadeTime or 0.1
	if self.currentTrack then
		local name = self:_GetTrackName(self.currentTrack)
		if not except or name ~= except then
			self.currentTrack:Stop(fadeTime)
			self.currentTrack = nil
		end
	end
end

function AnimationController:_GetTrackName(track)
	for name, t in pairs(self.animationRegistry) do
		if t == track then return name end
	end
	return nil
end

function AnimationController:IsPlaying(slotName)
	if slotName then
		local t = self.animationRegistry[slotName]
		return t and t.IsPlaying
	end
	return self.currentTrack ~= nil and self.currentTrack.IsPlaying
end

function AnimationController:Reset()
	self:StopAll(nil, 0)
end

return AnimationController
