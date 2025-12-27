-- Test FSM Fix for Attack Loop Prevention

local StateMachine = require("src/shared/Modules/FSM/StateMachine")
local AttackState = require("src/shared/Modules/FSM/AttackState")
local IdleState = require("src/shared/Modules/FSM/IdleState")

print("Testing FSM Loop Prevention...")

-- Mock context
local context = {
    comboQueued = false,
    AnimationController = {
        PlayAttack = function() print("Playing attack animation") end,
        PlayIdle = function() print("Playing idle animation") end,
    },
    Controllers = {
        CombatController = {
            StartAttack = function() print("Starting attack") end,
            StopAttack = function() print("Stopping attack") end,
            IsAttackFinished = function() return false end, -- Mock not finished
        }
    }
}

-- Create states
local idleState = IdleState.new()
local attackState = AttackState.new()

-- Create FSM
local fsm = StateMachine.new(idleState, context)
fsm:RegisterState(idleState)
fsm:RegisterState(attackState)

print("Initial state:", fsm:GetState().name)

-- Test 1: Change to Attack
local success = fsm:ChangeState("Attack")
print("Change to Attack:", success, "Current state:", fsm:GetState().name)

-- Test 2: Try to change to Attack again (should fail)
success = fsm:ChangeState("Attack")
print("Attempt same state change:", success, "Current state:", fsm:GetState().name)

-- Test 3: Simulate Update until timeout (1 second)
local startTime = tick()
local dt = 0.1
while tick() - startTime < 1.2 do
    fsm:Update(dt)
    task.wait(dt)  -- Use task.wait for Roblox
end
print("After timeout, current state:", fsm:GetState().name)

-- Test 4: Check comboQueued reset
print("comboQueued after timeout:", context.comboQueued)

print("FSM Loop Prevention Test Complete")
