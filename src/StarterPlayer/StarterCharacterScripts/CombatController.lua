local CombatController = {}
CombatController.__index = CombatController

function CombatController.new(fsm, context)
	return setmetatable({
		fsm = fsm,
		context = context,
	}, CombatController)
end

function CombatController:HandleM1()
	if not self.context.weaponEquipped then return end

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
