local BaseState = require(script.Parent.BaseState)

local DashState = setmetatable({}, BaseState)
DashState.__index = DashState

function DashState.new()
	local self = setmetatable(BaseState.new("Dash"), DashState)
	return self
end

-- =====================
-- ENTER
-- =====================
function DashState:Enter(context)
	if not context or not context.Controllers then return end

	local dashController = context.Controllers.DashController
	local anim = context.AnimationController
	if not dashController or not anim then return end

	local humanoid = context.Humanoid
	local root = context.Root

	local moveDir = humanoid.MoveDirection
	if moveDir.Magnitude < 0.1 then
		moveDir = root.CFrame.LookVector
	end

	-- Convert to local space for animation selection
	local localDir = root.CFrame:VectorToObjectSpace(moveDir.Unit)

	-- 🔥 PLAY DASH ANIMATION (THE FIX)
	anim:PlayDash(localDir)

	-- Movement
	dashController:Dash(moveDir)
end

-- =====================
-- UPDATE
-- =====================
function DashState:Update(dt, context)
	if not context or not context.Controllers then return end

	local dashController = context.Controllers.DashController
	if not dashController then return end

	if not dashController:IsDashing() then
    local humanoid = context.Humanoid

    -- 🔥 nếu còn đang di chuyển → Move
    if humanoid.MoveDirection.Magnitude > 0.05 then
        context.StateMachine:ChangeState(context.States.Move)
    else
        context.StateMachine:ChangeState(context.States.Idle)
    end
end

end

-- =====================
-- EXIT
-- =====================
function DashState:Exit(context)
	if not context then return end

	local dashController = context.Controllers and context.Controllers.DashController
	if dashController then
		dashController:Stop()
	end

	-- Stop dash animation
	if context.AnimationController and context.AnimationController.StopDash then
		context.AnimationController:StopDash()
	end
end

return DashState
