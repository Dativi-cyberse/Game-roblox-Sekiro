-- BlockState.lua
-- Block state: Character is blocking

local BaseState = require(script.Parent.BaseState)

local BlockState = setmetatable({}, BaseState)
BlockState.__index = BlockState

function BlockState.new()
	local self = setmetatable(BaseState.new("Block"), BlockState)
	self.allowedTransitions = {
		["Idle"] = true,
		["Move"] = true,
		["Parry"] = true, -- Can parry from block
		["HitStun"] = true,
		["Death"] = true,
	}
	return self
end

function BlockState:Enter(prevState, context)
	-- Start blocking
	if context.Controllers and context.Controllers.CombatController then
		context.Controllers.CombatController:StartBlock()
	end
end

function BlockState:Exit(nextState, context)
	-- Stop blocking
	if context.Controllers and context.Controllers.CombatController then
		context.Controllers.CombatController:StopBlock()
	end
end

function BlockState:Update(dt, context)
	-- Update block state
end

return BlockState
