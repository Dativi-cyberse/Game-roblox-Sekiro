-- CombatController.lua
-- Handles high-level combat intent (Mugen style)

local CombatController = {}
CombatController.__index = CombatController

function CombatController.new(fsm, context)
	local self = setmetatable({}, CombatController)

	self.fsm = fsm
	self.context = context

	return self
end

function CombatController:HandleM1()
	if not self.context.weaponEquipped then return end

	-- [FIX] Prevent intent leak. If attacking, let FSM HandleInput manage combo.
	local state = self.fsm:GetState()
	if state and state.name == "Attack" then
		return
	end

	self.context.attackRequested = true
end

function CombatController:SetGuarding(isGuarding)
	if self.context.weaponEquipped then
		self.context.blockRequested = isGuarding
	end
end

return CombatController
