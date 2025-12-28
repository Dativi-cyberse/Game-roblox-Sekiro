local RunService = game:GetService("RunService")

local DashController = {}
DashController.__index = DashController

local DASH_SPEED = 70
local DASH_TIME = 0.35
local DASH_COOLDOWN = 0.5

function DashController.new(root)
	local self = setmetatable({}, DashController)

	self.root = root
	self.isDashing = false
	self.lastDash = 0

	self.velocity = Instance.new("LinearVelocity")
	self.velocity.Attachment0 = Instance.new("Attachment", root)
	self.velocity.MaxForce = math.huge
	self.velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	self.velocity.Enabled = false
	self.velocity.Parent = root

	return self
end

function DashController:Dash(direction)
	if self.isDashing then return end
	if tick() - self.lastDash < DASH_COOLDOWN then return end

	self.isDashing = true
	self.lastDash = tick()

	self.velocity.VectorVelocity = direction.Unit * DASH_SPEED
	self.velocity.Enabled = true

	task.delay(DASH_TIME, function()
		self:Stop()
	end)
end

function DashController:Stop()
	if not self.isDashing then return end
	self.isDashing = false
	self.velocity.Enabled = false
end

function DashController:IsDashing()
	return self.isDashing
end

return DashController
