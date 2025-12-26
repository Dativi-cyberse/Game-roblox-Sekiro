-- ParryController.lua
-- Handles parry timing window logic
-- WHY: Separating parry logic makes it easier to tune timing and add feedback

local ParryController = {}
ParryController.__index = ParryController

-- Configuration
local DEFAULT_PARRY_WINDOW = 0.2 -- seconds
local DEFAULT_COOLDOWN = 0.1 -- Minimum time between parry attempts

function ParryController.new(parryWindow, cooldown)
	local self = setmetatable({}, ParryController)
	
	self.parryWindow = parryWindow or DEFAULT_PARRY_WINDOW
	self.cooldown = cooldown or DEFAULT_COOLDOWN
	
	self.parryIntentTime = 0
	self.lastParryTime = 0
	self.isParryActive = false
	
	self.parrySuccessSignal = Instance.new("BindableEvent")
	self.parryFailedSignal = Instance.new("BindableEvent")
	
	return self
end

--- Attempts to parry (called on input)
-- @return boolean - True if parry was registered
function ParryController:AttemptParry()
	local now = tick()
	
	-- Check cooldown
	if now - self.lastParryTime < self.cooldown then
		return false -- On cooldown
	end
	
	self.parryIntentTime = now
	self.lastParryTime = now
	self.isParryActive = true
	
	-- Auto-disable after window expires
	task.delay(self.parryWindow, function()
		if self.isParryActive and tick() - self.parryIntentTime >= self.parryWindow then
			self.isParryActive = false
		end
	end)
	
	return true
end

--- Checks if parry window is active when an attack arrives
-- WHY: Server validates timing, but client can check for visual feedback
-- @param attackTime number - When the attack was initiated
-- @return boolean - True if parry succeeded
function ParryController:CheckParry(attackTime)
	if not self.isParryActive then
		return false
	end
	
	local timeDiff = math.abs(self.parryIntentTime - attackTime)
	local success = timeDiff <= self.parryWindow
	
	self.isParryActive = false
	
	if success then
		self.parrySuccessSignal:Fire()
	else
		self.parryFailedSignal:Fire()
	end
	
	return success
end

--- Checks if parry window is currently active
-- @return boolean
function ParryController:IsParryActive()
	return self.isParryActive and (tick() - self.parryIntentTime <= self.parryWindow)
end

--- Cancels active parry window
function ParryController:CancelParry()
	self.isParryActive = false
	self.parryIntentTime = 0
end

--- Connects callback to parry success
-- @param callback function()
-- @return RBXScriptConnection
function ParryController:OnParrySuccess(callback)
	return self.parrySuccessSignal.Event:Connect(callback)
end

--- Connects callback to parry failure
-- @param callback function()
-- @return RBXScriptConnection
function ParryController:OnParryFailed(callback)
	return self.parryFailedSignal.Event:Connect(callback)
end

--- Resets parry controller
function ParryController:Reset()
	self.parryIntentTime = 0
	self.lastParryTime = 0
	self.isParryActive = false
end

return ParryController

