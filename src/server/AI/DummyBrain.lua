-- d:\Game-roblox-Sekiro\src\server\AI\DummyBrain.lua
-- DummyBrain.lua
-- Pure logic module for NPC decision making.
-- Returns INTENT (Attack/Guard/Parry/nil) based on state and target.

local DummyBrain = {}
DummyBrain.__index = DummyBrain

local ATTACK_RANGE = 6
local AGGRO_RANGE = 14
local DISENGAGE_RANGE = 18

function DummyBrain.new()
    local self = setmetatable({}, DummyBrain)
    self.lastDecisionTime = 0
    self.attackCooldown = 2
    return self
end

function DummyBrain:Decide(entity, targetEntity, dt)
    local now = os.clock()
    
    -- 1. Safety & Validation
    if not entity or not targetEntity or not entity.RootPart or not targetEntity.RootPart then
        return nil
    end

    -- 2. Status Check (Stagger/Posture)
    if (entity.Posture and entity.Posture <= 0) or (entity._staggerUntil and entity._staggerUntil > now) then
        return nil
    end

    -- 3. State Check (Can we decide?)
    -- We only decide if we are in a neutral or actionable state
    local state = entity.State
    -- [FIX] Allow "Attack" state to enable combos
    if state ~= "Idle" and state ~= "Move" and state ~= "Block" and state ~= "Attack" and state ~= "Guard" then
        return nil
    end

    -- 4. Throttle Decisions (Reaction Time)
    if now - self.lastDecisionTime < 0.1 then
        return nil
    end
    self.lastDecisionTime = now

    -- 5. Analyze Situation
    local dist = (entity.RootPart.Position - targetEntity.RootPart.Position).Magnitude
    
    -- [FIX] Disengage if too far
    if dist > DISENGAGE_RANGE then
        return nil
    end

    -- Check if target is attacking (using intent time for responsiveness)
    local targetAttacking = false
    if targetEntity._lastAttackIntentTime and (now - targetEntity._lastAttackIntentTime < 0.5) then
        targetAttacking = true
    end
    
    -- 6. Decision Logic
    
    -- PARRY: High priority if target is attacking and close
    if targetAttacking and dist < 8 then
        -- 40% chance to parry if skilled (could be configurable)
        if math.random() > 0.6 then
            return "Parry"
        end
        -- Fallback to Guard if parry fails
        return "Guard"
    end
    
    -- ATTACK: If close and cooldown ready
    local canAttack = (now - (entity._lastAttackTime or 0) > self.attackCooldown)
    -- [FIX] Allow combo chaining if already attacking
    if state == "Attack" then canAttack = true end
    
    if canAttack and dist < ATTACK_RANGE then
        -- return "Attack" -- Logic handled below to ensure cooldown check passes if not comboing
    end
    
    -- GUARD: If target is close and we are cautious, or target is attacking
    if dist < 10 and targetAttacking then
        return "Guard"
    end
    
    if canAttack and dist < ATTACK_RANGE then
        return "Attack"
    end

    -- IDLE/CHASE: If no combat action, return nil (DummyEnemy handles movement)
    return nil
end

return DummyBrain
