-- CombatConfig.lua
-- Centralized configuration for Sekiro-style combat system
-- All timing values in seconds unless otherwise noted

local CombatConfig = {}

-- =====================================================
-- POSTURE SYSTEM
-- =====================================================

CombatConfig.Posture = {
	MaxPosture = 100,                    -- Maximum posture value
	RecoveryRate = 8,                    -- Posture regenerated per second when safe
	RecoveryDelay = 0.5,                 -- Delay after last combat action before recovery starts
	BreakDuration = 1.5,                 -- Duration of stagger when posture breaks
	
	-- Posture damage sources
	AttackCost = 5,                      -- Posture cost for attacker when attacking
	BlockedAttackCost = 10,              -- Posture cost for defender when blocking
	ParriedCost = 25,                    -- Posture cost for attacker when parried (huge penalty)
	FailedParryCost = 20,                -- Posture cost for defender on failed parry attempt
}

-- =====================================================
-- PARRY SYSTEM (MOST IMPORTANT)
-- =====================================================

CombatConfig.Parry = {
	Window = 0.2,                        -- Active parry timing window (seconds)
	GracePeriod = 0.05,                  -- Additional server-side tolerance
	Cooldown = 0.1,                      -- Minimum time between parry attempts
	PostureDamage = 35,                  -- Posture damage dealt to attacker on successful parry
	PosturePenalty = 3,                  -- Small posture cost for defender on successful parry
	
	-- Failed parry penalties
	FailedPostureDamage = 20,            -- Posture damage taken on failed parry
	FailedHealthDamageMultiplier = 1.2,  -- Health damage multiplier when parry fails
	
	-- Visual/Audio feedback
	SparkEffect = true,                  -- Play spark effect on successful parry
	SoundEffect = true,                  -- Play distinct sound on parry
}

-- =====================================================
-- BLOCK SYSTEM
-- =====================================================

CombatConfig.Block = {
	HealthReduction = 0.3,               -- Multiplier for health damage when blocking (70% reduction)
	PostureDamageMultiplier = 1.0,       -- Multiplier for posture damage when blocking
	UnblockableMultiplier = 2.5,         -- Posture damage multiplier for unblockable attacks
}

-- =====================================================
-- ATTACK SYSTEM
-- =====================================================

CombatConfig.Attack = {
	BaseDamage = 12,                     -- Base health damage per attack
	BasePostureDamage = 15,              -- Base posture damage per attack
	Range = 6.0,                         -- Attack range in studs
	Cooldown = 0.3,                      -- Minimum time between attacks (anti-spam)
	ComboWindow = 1.2,                   -- Time window to continue combo chain
}

-- =====================================================
-- DEATHBLOW SYSTEM
-- =====================================================

CombatConfig.Deathblow = {
	ActivationRange = 8.0,               -- Maximum range to trigger deathblow
	LockDuration = 2.5,                  -- Duration both characters are locked during deathblow
	KillHealthThreshold = 0,             -- Health threshold to allow deathblow (0 = only on posture break)
	AnimationDuration = 1.8,             -- Deathblow animation duration
}

-- =====================================================
-- COMBAT STATES
-- =====================================================

CombatConfig.State = {
	-- State transition timings
	AttackRecoveryTime = 0.4,            -- Time after attack ends before returning to idle
	ParryRecoveryTime = 0.2,             -- Time after parry before next action allowed
	StaggerRecoveryTime = 1.5,           -- Time to recover from posture break
}

-- =====================================================
-- ANIMATION MARKERS
-- =====================================================

-- Expected marker names in combat animations
CombatConfig.Markers = {
	HitStart = "HitStart",               -- Marker when hit detection begins
	HitEnd = "HitEnd",                   -- Marker when hit detection ends
	ParryWindow = "ParryWindow",         -- Marker for parry timing window
	Deathblow = "Deathblow",             -- Marker for deathblow execution
}

-- =====================================================
-- HITBOX SYSTEM
-- =====================================================

CombatConfig.Hitbox = {
	Size = Vector3.new(4, 4, 5),         -- Hitbox dimensions (width, height, depth)
	ForwardOffset = 2.5,                 -- Forward offset from character root
	Duration = 0.15,                     -- Hitbox active duration (tied to HitStart/HitEnd markers)
}

-- =====================================================
-- WEAPON PRESETS
-- =====================================================

CombatConfig.Weapons = {
	Katana = {
		BaseDamage = 12,
		BasePostureDamage = 15,
		AttackSpeed = 1.0,
		Range = 6.0,
		ComboChain = 5,                  -- Number of attacks in combo chain
	},
}

-- =====================================================
-- EXPANSION: PERILOUS ATTACKS (future)
-- =====================================================

CombatConfig.Perilous = {
	Unblockable = true,                  -- Perilous attacks cannot be blocked
	PostureDamageMultiplier = 2.0,       -- Increased posture damage
	HealthDamageMultiplier = 1.5,        -- Increased health damage
}

-- Export
return CombatConfig