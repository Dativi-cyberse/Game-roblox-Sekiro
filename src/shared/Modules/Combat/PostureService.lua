-- PostureService.lua
-- Handles posture management, regeneration, and break detection
-- WHY: Centralizes posture logic for consistency across combat system

local CombatConfig = require(script.Parent.Parent.Parent.CombatConfig)

local PostureService = {}

-- =====================================================
-- POSTURE MANAGEMENT
-- =====================================================

--- Adds posture damage to a character
-- @param characterState table - Character state object with Posture field
-- @param amount number - Amount of posture damage to apply
-- @return boolean - True if posture was broken
function PostureService.ApplyPostureDamage(characterState, amount)
	if not characterState or type(amount) ~= "number" then
		return false
	end
	
	-- Ensure posture exists
	characterState.Posture = characterState.Posture or CombatConfig.Posture.MaxPosture
	characterState.MaxPosture = characterState.MaxPosture or CombatConfig.Posture.MaxPosture
	
	-- Apply damage (posture increases as it takes damage, like a bar filling)
	local oldPosture = characterState.Posture
	characterState.Posture = math.clamp(
		characterState.Posture + math.max(0, amount),
		0,
		characterState.MaxPosture
	)
	
	-- Update last combat action time (prevents immediate regeneration)
	characterState._lastCombatActionTime = tick()
	
	-- Check if posture broke
	local wasBroken = oldPosture < characterState.MaxPosture and characterState.Posture >= characterState.MaxPosture
	if wasBroken then
		characterState._postureBreakTime = tick()
	end
	
	return wasBroken
end

--- Checks if character's posture is broken
-- @param characterState table - Character state object
-- @return boolean - True if posture >= max (broken)
function PostureService.IsPostureBroken(characterState)
	if not characterState then return false end
	
	local posture = characterState.Posture or 0
	local maxPosture = characterState.MaxPosture or CombatConfig.Posture.MaxPosture
	
	return posture >= maxPosture
end

--- Regenerates posture over time when not in combat
-- WHY: Posture regenerates slowly when safe, encouraging defensive play
-- @param characterState table - Character state object
-- @param deltaTime number - Time since last frame
-- @return boolean - True if posture was regenerated
function PostureService.RegeneratePosture(characterState, deltaTime)
	if not characterState or not deltaTime then
		return false
	end
	
	-- Ensure posture exists
	characterState.Posture = characterState.Posture or 0
	characterState.MaxPosture = characterState.MaxPosture or CombatConfig.Posture.MaxPosture
	
	-- Can't regenerate if already at 0 (already broken, waiting for recovery)
	if characterState.Posture >= characterState.MaxPosture then
		return false
	end
	
	-- Check if enough time has passed since last combat action
	local lastActionTime = characterState._lastCombatActionTime or 0
	local timeSinceAction = tick() - lastActionTime
	
	if timeSinceAction < CombatConfig.Posture.RecoveryDelay then
		return false -- Still in combat, no regeneration
	end
	
	-- Calculate regeneration amount
	local regenAmount = CombatConfig.Posture.RecoveryRate * deltaTime
	local oldPosture = characterState.Posture
	
	-- Regenerate (reduce posture towards 0)
	characterState.Posture = math.max(0, characterState.Posture - regenAmount)
	
	return characterState.Posture ~= oldPosture
end

--- Resets posture after break recovery
-- @param characterState table - Character state object
function PostureService.ResetPosture(characterState)
	if not characterState then return end
	
	characterState.Posture = 0
	characterState.MaxPosture = characterState.MaxPosture or CombatConfig.Posture.MaxPosture
	characterState._lastCombatActionTime = nil
	characterState._postureBreakTime = nil
end

--- Gets the posture percentage (0 = no damage, 1 = broken)
-- @param characterState table - Character state object
-- @return number - Posture percentage (0-1)
function PostureService.GetPosturePercentage(characterState)
	if not characterState then return 0 end
	
	local posture = characterState.Posture or 0
	local maxPosture = characterState.MaxPosture or CombatConfig.Posture.MaxPosture
	
	if maxPosture == 0 then return 0 end
	
	return math.clamp(posture / maxPosture, 0, 1)
end

return PostureService


