-- HitStunState.lua
-- JJS x Mugen style HitStun (Bao gồm Knockback và Ragdoll)

local BaseState = require(script.Parent.BaseState)

local HitStunState = setmetatable({}, BaseState)
HitStunState.__index = HitStunState

function HitStunState.new()
	local self = setmetatable(BaseState.new("HitStun"), HitStunState)
	self.allowedTransitions = {
		["Idle"] = true,
		["Move"] = true,
		["Death"] = true,
	}
	return self
end

function HitStunState:Enter(prevState, context)
	local hitData = context.lastHitData or {}
	self.startTime = os.clock()

	-- Lấy Humanoid để xử lý ngã
	local humanoid = context.Root and context.Root.Parent:FindFirstChildOfClass("Humanoid")
	self.humanoid = humanoid

	if hitData.IsFinisher then
		-- [JJS STYLE]: BỊ ĐÁNH BAY VÀ NGÃ (RAGDOLL)
		self.isRagdolled = true
		self.stunDuration = 1.5 -- Nằm sân 1.5 giây
		
		if self.humanoid then
			self.humanoid.PlatformStand = true -- Làm nhân vật mất kiểm soát (Ngã)
		end

		-- Áp dụng lực hất văng (Knockback)
		if context.Root and hitData.AttackerCFrame then
			-- Tính hướng văng: Điểm đánh -> Nạn nhân
			local direction = (context.Root.Position - hitData.AttackerCFrame.Position).Unit
			-- Hất hơi chếch lên trên để bay đẹp hơn
			direction = Vector3.new(direction.X, 0.5, direction.Z).Unit 
			
			local knockbackForce = 75 -- Lực bay, đệ có thể tăng giảm
			context.Root.AssemblyLinearVelocity = direction * knockbackForce
		end

		-- Nếu đệ có animation bay trên không thì gọi ở đây
		if context.AnimationController and context.AnimationController.PlayKnockback then
			context.AnimationController:PlayKnockback()
		end

	else
		-- [SEKIRO STYLE]: CHỈ BỊ KHỰNG NHẸ (ĐÒN M1 THƯỜNG)
		self.isRagdolled = false
		self.stunDuration = 0.4 -- Chỉ khựng 0.4 giây

		if context.AnimationController then
			context.AnimationController:PlayHitStun()
		end
		
		-- Dừng nhân vật lại (bị khựng thì không trượt đi)
		if context.Root then
			context.Root.AssemblyLinearVelocity = Vector3.new(0, context.Root.AssemblyLinearVelocity.Y, 0)
		end
	end

	if context.Controllers and context.Controllers.CombatController then
		context.Controllers.CombatController:StartHitStun()
	end
end

function HitStunState:Update(dt, context)
	-- Thoát trạng thái dựa trên thời gian Stun
	if os.clock() - self.startTime >= self.stunDuration then
		if context.StateMachine and context.States and context.States.Idle then
			context.StateMachine:ChangeState(context.States.Idle)
		end
	end
end

function HitStunState:Exit(nextState, context)
	-- Dọn dẹp: Đứng dậy sau khi ngã
	if self.isRagdolled and self.humanoid then
		self.humanoid.PlatformStand = false
	end

	if context.Controllers and context.Controllers.CombatController then
		context.Controllers.CombatController:StopHitStun()
	end
end

return HitStunState