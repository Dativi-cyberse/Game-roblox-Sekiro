-- PostureController.lua
-- Manages posture value, regeneration, and break detection
-- WHY: Centralized posture logic enables consistent behavior across combat systems

local PostureController = {}
PostureController.__index = PostureController

-- Configuration
local DEFAULT_MAX_POSTURE = 100
local DEFAULT_RECOVERY_RATE = 8 -- Posture per second
local DEFAULT_RECOVERY_DELAY = 0.5 -- Delay before recovery starts

function PostureController.new(maxPosture, recoveryRate, recoveryDelay)
	local self = setmetatable({}, PostureController)
	
	self.maxPosture = maxPosture or DEFAULT_MAX_POSTURE
	self.recoveryRate = recoveryRate or DEFAULT_RECOVERY_RATE
	self.recoveryDelay = recoveryDelay or DEFAULT_RECOVERY_DELAY
	
	self.currentPosture = 0
	self.lastCombatActionTime = 0
	self.isBroken = false
	
	self.postureChangedSignal = Instance.new("BindableEvent")
	self.postureBrokenSignal = Instance.new("BindableEvent")
	
	return self
end

--- Adds posture damage
-- @param amount number - Amount to add
-- @return boolean - True if posture broke
function PostureController:AddPosture(amount)
	if self.isBroken then
		return false -- Already broken
	end
	
	local oldPosture = self.currentPosture
	self.currentPosture = math.min(self.currentPosture + amount, self.maxPosture)
	self.lastCombatActionTime = tick()
	
	-- Check if broke
	if self.currentPosture >= self.maxPosture and oldPosture < self.maxPosture then
		self.isBroken = true
		self.postureBrokenSignal:Fire()
		return true
	end
	
	-- Fire changed signal
	if oldPosture ~= self.currentPosture then
		self.postureChangedSignal:Fire(self.currentPosture, self.maxPosture)
	end
	
	return false
end

--- Reduces posture (regeneration)
-- @param amount number - Amount to reduce
function PostureController:ReducePosture(amount)
	if self.currentPosture <= 0 then
		return
	end
	
	local oldPosture = self.currentPosture
	self.currentPosture = math.max(0, self.currentPosture - amount)
	
	-- If regenerated below break threshold, un-break
	if self.isBroken and self.currentPosture < self.maxPosture * 0.9 then
		self.isBroken = false
	end
	
	-- Fire changed signal
	if oldPosture ~= self.currentPosture then
		self.postureChangedSignal:Fire(self.currentPosture, self.maxPosture)
	end
end

--- Gets current posture value
-- @return number
function PostureController:GetPosture()
	return self.currentPosture
end

--- Gets posture percentage (0-1)
-- @return number
function PostureController:GetPosturePercentage()
	return self.currentPosture / self.maxPosture
end

--- Checks if posture is broken
-- @return boolean
function PostureController:IsBroken()
	return self.isBroken
end

--- Updates posture regeneration (call every frame)
-- @param deltaTime number
function PostureController:Update(deltaTime)
	if self.isBroken or self.currentPosture <= 0 then
		return
	end
	
	-- Check if enough time has passed since last combat action
	local timeSinceAction = tick() - self.lastCombatActionTime
	if timeSinceAction < self.recoveryDelay then
		return -- Still in combat
	end
	
	-- Regenerate posture
	local regenAmount = self.recoveryRate * deltaTime
	self:ReducePosture(regenAmount)
end

--- Resets posture to zero
function PostureController:Reset()
	self.currentPosture = 0
	self.lastCombatActionTime = 0
	self.isBroken = false
	self.postureChangedSignal:Fire(0, self.maxPosture)
end

--- Connects callback to posture changes
-- @param callback function(current, max)
-- @return RBXScriptConnection
function PostureController:OnPostureChanged(callback)
	return self.postureChangedSignal.Event:Connect(callback)
end

--- Connects callback to posture break
-- @param callback function()
-- @return RBXScriptConnection
function PostureController:OnPostureBroken(callback)
	return self.postureBrokenSignal.Event:Connect(callback)
end

return PostureController

