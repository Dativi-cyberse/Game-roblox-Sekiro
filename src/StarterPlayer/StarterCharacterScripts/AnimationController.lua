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

	Slash1 = "131822813695057",
	Slash2 = "122160066715450",
	Slash3 = "124228947503532",
	Slash4 = "111207431242662",
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
			-- Priority (VERY IMPORTANT)
			if name == "Idle" then
				track.Priority = Enum.AnimationPriority.Idle
			elseif name == "Sprint" then
				track.Priority = Enum.AnimationPriority.Movement
			else
				track.Priority = Enum.AnimationPriority.Action
			end

			-- Loop settings
			track.Looped = (name == "Idle" or name == "Guard" or name == "Sprint")

			self.animationRegistry[name] = track
		else
			warn("[AnimationController] Failed to load animation:", name, "with ID:", id)
		end
	end

	-- Correct count (dictionary-safe)
	local count = 0
	for _ in pairs(self.animationRegistry) do
		count += 1
	end

	print("[AnimationController] Loaded", count, "animations")
end

-- =====================================================
-- PUBLIC PLAY METHODS
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

function AnimationController:PlaySlash(index)
	local name = "Slash" .. index
	return self:_PlayAnimation(name, 0.05)
end

function AnimationController:PlayAttack()
	-- Map to first slash animation
	return self:PlaySlash(1)
end

function AnimationController:PlayDeath()
	-- Placeholder for death animation
	warn("[AnimationController] PlayDeath not implemented")
end

function AnimationController:PlayHitStun()
	-- Placeholder for hit stun animation
	warn("[AnimationController] PlayHitStun not implemented")
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

	-- Stop previous track
	if self.currentTrack and self.currentTrack ~= track then
		self.currentTrack:Stop(fadeTime)
	end

	track:Play(fadeTime)
	self.currentTrack = track

	self:_ConnectMarkers(track, slotName)
	self.animationPlayedSignal:Fire(slotName, track)

	-- IMPORTANT: use Stopped (not Ended)
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

	local markerNames = { "Hit", "ParryWindow", "ComboAllow" }

	for _, markerName in ipairs(markerNames) do
		local ok, signal = pcall(function()
			return track:GetMarkerReachedSignal(markerName)
		end)

		if ok and signal then
			local conn = signal:Connect(function()
				-- marker hook (handled elsewhere)
			end)
			table.insert(self.markerConnections[slotName], conn)
		end
	end
end

-- =====================================================
-- STATE / UTIL
-- =====================================================

function AnimationController:StopAll(except, fadeTime)
	fadeTime = fadeTime or 0.1

	if self.currentTrack then
		local currentName = self:_GetTrackName(self.currentTrack)
		if not except or currentName ~= except then
			self.currentTrack:Stop(fadeTime)
			self.currentTrack = nil
		end
	end
end

function AnimationController:_GetTrackName(track)
	for name, t in pairs(self.animationRegistry) do
		if t == track then
			return name
		end
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

function AnimationController:OnAnimationPlayed(cb)
	return self.animationPlayedSignal.Event:Connect(cb)
end

function AnimationController:OnAnimationEnded(cb)
	return self.animationEndedSignal.Event:Connect(cb)
end

function AnimationController:Cleanup()
	for _, list in pairs(self.markerConnections) do
		for _, c in ipairs(list) do
			pcall(function() c:Disconnect() end)
		end
	end
	self.markerConnections = {}
	self:StopAll(nil, 0)
	self.animationRegistry = {}
end

function AnimationController:Reset()
	self:StopAll(nil, 0)
end

return AnimationController
