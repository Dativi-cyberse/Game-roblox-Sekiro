-- DummyBrain.lua
-- Simple decision making logic for the Dummy.
-- Determines INTENT, not state execution.

local DummyBrain = {}
DummyBrain.__index = DummyBrain

function DummyBrain.new()
	local self = setmetatable({}, DummyBrain)
	self.nextDecisionTime = 0
	-- HOTFIX
	self.lastDecisionTime = 0
	-- HOTFIX
	self.attackCooldown = 2
	-- HOTFIX
	self.recoveryWindow = 0.5
	return self
end

-- Returns a string action: "Attack", "Guard", "Parry", "Idle", or nil (no decision)
-- function DummyBrain:Decide(entity, target, dt)
-- 	local now = os.clock()
	
-- 	-- Don't make decisions too frequently
-- 	if now < self.nextDecisionTime then
-- 		return nil
-- 	end
	
-- 	-- Default decision interval
-- 	self.nextDecisionTime = now + 0.5

-- 	if not target or not target.Parent or not entity.RootPart then
-- 		return "Idle"
-- 	end
	
-- 	-- Ensure target has a root part
-- 	local targetRoot = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Torso") or target.PrimaryPart
-- 	if not targetRoot then
-- 		return "Idle"
-- 	end

-- 	local dist = (entity.RootPart.Position - targetRoot.Position).Magnitude

-- 	-- Simple Logic:
-- 	-- 1. If very close, high chance to Attack or Parry
-- 	-- 2. If medium range, chance to Guard
-- 	-- 3. If far, Idle
	
-- 	if dist < 8 then
-- 		local roll = math.random()
-- 		if roll < 0.5 then
-- 			return "Attack"
-- 		elseif roll < 0.8 then
-- 			-- Attempt a parry (sets intent time)
-- 			return "Parry"
-- 		else
-- 			return "Guard"
-- 		end
-- 	elseif dist < 15 then
-- 		local roll = math.random()
-- 		if roll < 0.4 then
-- 			return "Guard"
-- 		else
-- 			return "Idle"
-- 		end
-- 	else
-- 		return "Idle"
-- 	end
-- end
function DummyBrain:Decide(entity, targetEntity, dt)
    print("[DummyBrain] Decide called")

    -- HOTFIX: Time-based decision logic
    local now = os.clock()
    -- HOTFIX: Posture safety check
    if entity.Posture <= 0 or entity._staggerUntil > now then
        return nil
    end
    -- HOTFIX: Only decide in Idle or Guard states
    if entity.State ~= "Idle" and entity.State ~= "Guarding" then
        return nil
    end
    -- HOTFIX: Throttle decisions
    if now - self.lastDecisionTime < 0.1 then
        return nil
    end
    self.lastDecisionTime = now
    -- HOTFIX: Check attack cooldown
    local canAttack = (now - entity._lastAttackTime > self.attackCooldown)
    -- HOTFIX: Heuristic for player attacking
    local playerAttacking = targetEntity and targetEntity.State == "Attacking"
    -- HOTFIX: Calculate distance
    local dist = 0
    if targetEntity and targetEntity.RootPart and entity.RootPart then
        dist = (entity.RootPart.Position - targetEntity.RootPart.Position).Magnitude
    end
    -- HOTFIX: Decision logic
    if playerAttacking and dist < 8 then
        entity.parryIntentTime = now
        return "Parry"
    elseif canAttack and dist < 8 then
        return "Attack"
    elseif dist < 15 then
        return "Guard"
    else
        return nil
    end
end

return DummyBrain
