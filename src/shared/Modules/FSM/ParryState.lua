-- ParryState.lua
-- Parry state: Character is attempting a parry

local BaseState = require(script.Parent.BaseState)

local ParryState = setmetatable({}, BaseState)
ParryState.__index = ParryState

function ParryState.new()
	local self = setmetatable(BaseState.new("Parry"), ParryState)
	self.allowedTransitions = {
		["Idle"] = true,
		["Move"] = true,
		["HitStun"] = true,
		["Death"] = true,
	}
	return self
end

function ParryState:Enter(prevState, context)
	-- Start parry window
	if context.Controllers and context.Controllers.CombatController then
		context.Controllers.CombatController:StartParry()
	end
end

function ParryState:Exit(nextState, context)
	-- End parry window
	if context.Controllers and context.Controllers.CombatController then
		context.Controllers.CombatController:StopParry()
	end
end

function ParryState:Update(dt, context)
	-- Check if parry window has expired
	if context.Controllers and context.Controllers.CombatController then
		if context.Controllers.CombatController:IsParryExpired() then
			-- Transition back to Idle
		end
	end
end

return ParryState
