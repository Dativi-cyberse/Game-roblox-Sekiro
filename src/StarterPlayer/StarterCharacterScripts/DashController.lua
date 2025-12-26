-- DashController.lua
-- Handles directional dash/step dodge movement
-- WHY: Separating dash logic allows easy tuning of speed, duration, cooldown

local DashController = {}
DashController.__index = DashController

-- Configuration
local DEFAULT_DASH_SPEED = 50 -- studs per second
local DEFAULT_DASH_DURATION = 0.15 -- seconds
local DEFAULT_DASH_COOLDOWN = 0.5 -- seconds

function DashController.new(dashSpeed, dashDuration, dashCooldown)
	local self = setmetatable({}, DashController)
	
	self.dashSpeed = dashSpeed or DEFAULT_DASH_SPEED
	self.dashDuration = dashDuration or DEFAULT_DASH_DURATION
	self.dashCooldown = dashCooldown or DEFAULT_DASH_COOLDOWN
	
	self.isDashing = false
	self.lastDashTime = 0
	self.dashVelocity = Vector3.new(0, 0, 0)
	
	self.dashStartedSignal = Instance.new("BindableEvent")
	self.dashEndedSignal = Instance.new("BindableEvent")
	
	return self
end

--- Attempts to dash in a direction
-- @param direction Vector3 - Normalized direction vector
-- @return boolean - True if dash started
function DashController:AttemptDash(direction)
	if self.isDashing then
		return false -- Already dashing
	end
	
	local now = tick()
	if now - self.lastDashTime < self.dashCooldown then
		return false -- On cooldown
	end
	
	-- Normalize direction and apply dash speed
	local normalizedDir = direction.Unit
	self.dashVelocity = normalizedDir * self.dashSpeed
	self.isDashing = true
	self.lastDashTime = now
	
	self.dashStartedSignal:Fire(normalizedDir)
	
	-- Auto-end dash after duration
	task.delay(self.dashDuration, function()
		if self.isDashing then
			self:EndDash()
		end
	end)
	
	return true
end

--- Gets current dash velocity
-- @return Vector3 - Velocity vector, or zero if not dashing
function DashController:GetDashVelocity()
	if not self.isDashing then
		return Vector3.new(0, 0, 0)
	end
	
	return self.dashVelocity
end

--- Checks if currently dashing
-- @return boolean
function DashController:IsDashing()
	return self.isDashing
end

--- Checks if dash is on cooldown
-- @return boolean
function DashController:IsOnCooldown()
	return tick() - self.lastDashTime < self.dashCooldown
end

--- Gets remaining cooldown time
-- @return number - Seconds remaining, or 0 if ready
function DashController:GetCooldownRemaining()
	local remaining = self.dashCooldown - (tick() - self.lastDashTime)
	return math.max(0, remaining)
end

--- Ends dash early (called when dash duration expires or is interrupted)
function DashController:EndDash()
	if not self.isDashing then
		return
	end
	
	self.isDashing = false
	self.dashVelocity = Vector3.new(0, 0, 0)
	self.dashEndedSignal:Fire()
end

--- Connects callback to dash start
-- @param callback function(direction)
-- @return RBXScriptConnection
function DashController:OnDashStarted(callback)
	return self.dashStartedSignal.Event:Connect(callback)
end

--- Connects callback to dash end
-- @param callback function()
-- @return RBXScriptConnection
function DashController:OnDashEnded(callback)
	return self.dashEndedSignal.Event:Connect(callback)
end

--- Resets dash controller
function DashController:Reset()
	self:EndDash()
	self.lastDashTime = 0
end

return DashController

