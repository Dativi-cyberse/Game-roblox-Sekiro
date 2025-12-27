-- LocomotionController.lua
-- Handles Idle / Walk based on movement (Animator-only)

local RunService = game:GetService("RunService")

local LocomotionController = {}
LocomotionController.__index = LocomotionController

function LocomotionController.new(humanoid, animationController, stateMachine)
	local self = setmetatable({}, LocomotionController)

	self.humanoid = humanoid
	self.anim = animationController
	self.sm = stateMachine

	self.enabled = true
	self.lastMoving = false

	self.conn = RunService.RenderStepped:Connect(function()
		self:_Update()
	end)

	return self
end

function LocomotionController:_Update()
	if not self.enabled then
		return
	end

	local state = self.sm:GetState()
	if not state or state.name ~= "Idle" then
		return
	end

	local moving = self.humanoid.MoveDirection.Magnitude > 0.05

	if moving ~= self.lastMoving then
		self.lastMoving = moving

		if moving then
			self.anim:PlaySprint() -- dùng Sprint làm Walk
		else
			self.anim:PlayIdle()
		end
	end
end

function LocomotionController:SetEnabled(value)
	self.enabled = value
	if not value then
		self.anim:StopAll()
	end
end

function LocomotionController:Destroy()
	if self.conn then
		self.conn:Disconnect()
	end
end

return LocomotionController
