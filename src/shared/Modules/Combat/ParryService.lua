-- ParryService.lua
-- Handles parry timing, validation, and resolution
-- WHY: Parry is the core mechanic - needs precise timing window validation

local CombatConfig = require(script.Parent.Parent.Parent.CombatConfig)

local ParryService = {}

-- =====================================================
-- PARRY INTENT RECORDING
-- =====================================================

--- Records a parry attempt from a character
-- WHY: Client sends parry intent, server records timestamp for validation
-- @param characterState table - Character state object
function ParryService.RecordParryIntent(characterState)
	if not characterState then return end
	
	local now = tick()
	
	-- Check cooldown to prevent spam
	if characterState._lastParryTime then
		local timeSinceLastParry = now - characterState._lastParryTime
		if timeSinceLastParry < CombatConfig.Parry.Cooldown then
			return -- Parry on cooldown, ignore
		end
	end
	
	-- Record parry intent timestamp
	characterState._parryIntentTime = now
	characterState._lastParryTime = now
end

-- =====================================================
-- PARRY RESOLUTION
-- =====================================================

--- Resolves a parry attempt when an attack arrives
-- WHY: Validates if parry window overlaps with attack timing
-- @param defenderState table - Character attempting to parry
-- @param attackTime number - Timestamp when attack was initiated
-- @return table - { success: boolean, postureDamage: number }
function ParryService.ResolveParry(defenderState, attackTime)
	if not defenderState or not attackTime then
		return { success = false, postureDamage = 0 }
	end
	
	-- No parry intent recorded
	local parryIntentTime = defenderState._parryIntentTime
	if not parryIntentTime or parryIntentTime == 0 then
		return { success = false, postureDamage = 0 }
	end
	
	-- Calculate time difference between parry intent and attack
	local timeDiff = math.abs(parryIntentTime - attackTime)
	local parryWindow = CombatConfig.Parry.Window + CombatConfig.Parry.GracePeriod
	
	-- Check if parry window overlaps with attack
	if timeDiff <= parryWindow then
		-- Successful parry
		defenderState._parryIntentTime = nil -- Clear intent
		
		return {
			success = true,
			postureDamage = CombatConfig.Parry.PostureDamage,
			posturePenalty = CombatConfig.Parry.PosturePenalty, -- Small cost for parrying
		}
	else
		-- Failed parry (missed timing window)
		defenderState._parryIntentTime = nil -- Clear intent
		
		return {
			success = false,
			postureDamage = CombatConfig.Parry.FailedPostureDamage,
			healthDamageMultiplier = CombatConfig.Parry.FailedHealthDamageMultiplier,
		}
	end
end

--- Clears parry intent (call when parry window expires)
-- @param characterState table - Character state object
function ParryService.ClearParryIntent(characterState)
	if not characterState then return end
	
	characterState._parryIntentTime = nil
end

--- Checks if character has active parry intent
-- @param characterState table - Character state object
-- @return boolean - True if parry intent is active
function ParryService.HasParryIntent(characterState)
	if not characterState then return false end
	
	local intentTime = characterState._parryIntentTime
	if not intentTime or intentTime == 0 then
		return false
	end
	
	-- Check if intent is still within valid window (prevents stale intents)
	local now = tick()
	local timeSinceIntent = now - intentTime
	local maxWindow = CombatConfig.Parry.Window * 2 -- Allow double window for safety
	
	return timeSinceIntent <= maxWindow
end

return ParryService


