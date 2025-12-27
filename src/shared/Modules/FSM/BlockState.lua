local BaseState = require(script.Parent.BaseState)

local BlockState = setmetatable({}, BaseState)
BlockState.__index = BlockState

function BlockState.new()
	return setmetatable(BaseState.new("Block"), BlockState)
end

function BlockState:Enter(context)
	if not context.weaponEquipped then return end
	context.AnimationController:PlayGuard()
end

function BlockState:Exit(context)
	context.AnimationController:StopAll(nil, 0.1)
end

return BlockState
