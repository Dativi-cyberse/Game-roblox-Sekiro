-- HitStunState.lua
-- HitStun state: Character is stunned from taking damage

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
	-- Start hit stun animation and logic
	if context.AnimationController then
		context.AnimationController:PlayHitStun()
	end
	if context.Controllers and context.Controllers.CombatController then
		context.Controllers.CombatController:StartHitStun()
	end
end

function HitStunState:Exit(nextState, context)
	-- End hit stun
	if context.Controllers and context.Controllers.CombatController then
		context.Controllers.CombatController:StopHitStun()
	end
end

function HitStunState:Update(dt, context)
	-- Update hit stun progress
	if context.Controllers and context.Controllers.CombatController then
		if context.Controllers.CombatController:IsHitStunFinished() then
			-- Transition back to Idle or Move
			if context.StateMachine and context.States and context.States.Idle then -- HOTFIX: Guard transition
				context.StateMachine:ChangeState(context.States.Idle) -- HOTFIX: Transition to Idle when hit stun finishes
			end
		end
	end
end

return HitStunState
