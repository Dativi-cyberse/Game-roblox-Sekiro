local CombatController = {}
CombatController.__index = CombatController

function CombatController.new(fsm, context)
	return setmetatable({
		fsm = fsm,
		context = context,
	}, CombatController)
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")

function CombatController:HandleM1()
	if not self.context.weaponEquipped then return end

	-- PHASE 2: Check for Deathblow opportunity before normal attack.
	-- ASSUMPTION: A client-side targeting controller exists and is accessible via context.
	local lockedTarget
	if self.context.TargetingController and self.context.TargetingController.GetLockedTarget then
		lockedTarget = self.context.TargetingController:GetLockedTarget()
	end

	if lockedTarget and lockedTarget:GetAttribute("PostureBroken") == true then
		local DeathblowRemote = ReplicatedStorage.Shared.Remotes.Combat:FindFirstChild("Deathblow")
		if DeathblowRemote then
			DeathblowRemote:FireServer({ target = lockedTarget })
			-- Do not proceed with normal attack; the server will handle the deathblow.
			return
		end
	end

	local state = self.fsm:GetState()

	-- nếu đang Attack → buffer input
	if state == self.context.States.Attack then
		state:HandleInput("M1", self.context)
		return
	end

	-- chỉ Idle mới bắt đầu Attack
	if state == self.context.States.Idle then
		self.context.comboIndex = 1
		self.fsm:ChangeState(self.context.States.Attack)
	end
end



function CombatController:SetGuarding(on)
	if not self.context.weaponEquipped then return end

	local cur = self.fsm:GetState()
	local block = self.context.States.Block
	local idle = self.context.States.Idle

	if on then
		if cur ~= block then
			self.fsm:ChangeState(block)
		end
	else
		if cur == block then
			self.fsm:ChangeState(idle)
		end
	end
end

return CombatController
