
local CombatConfig = {}

-- General timing and windows
CombatConfig.ParryTimingWindow = 0.15 -- seconds (base parry timing window)
CombatConfig.ClashTimingWindow = 0.1 -- seconds to enter a clash
CombatConfig.StaggerDurations = {
  ParryStagger = 0.3,      -- seconds when parry succeeds
  GuardBreakStagger = 1.0, -- seconds when guard reaches 0
}

-- Parry settings
CombatConfig.Parry = {
  SuccessGuardDamage = 30, -- guard damage applied to enemy when parry succeeds
}

-- Clash settings
CombatConfig.Clash = {
  GuardLossRate = 40,                -- guard per second lost during clash
  PlayerPushGuardThreshold = 50,     -- pushback occurs when player's guard <= this
  BossGuardLossCapFraction = 0.2,    -- max fraction of boss guard reduced in clash
}

-- Critical strike limits
CombatConfig.Critical = {
  BossCapFraction = 0.2,   -- 20% of boss max HP
  NormalCapFraction = 0.66,-- 66% of normal enemy max HP
}

-- Weapon presets
CombatConfig.Weapons = {
  Sword = {
    BaseDamage = 10,
    GuardDamage = 10,
    AttackSpeed = 1.0,
    Range = 5.0,
    Hits = 1,
  },
  DualDaggers = {
    BaseDamage = 6,
    GuardDamage = 6,
    AttackSpeed = 1.6,
    Range = 3.5,
    Hits = 2,
  },
  MagicStaff = {
    BaseDamage = 12,
    GuardDamage = 8,
    AttackSpeed = 0.7,
    Range = 7.0,
    Hits = 1,
    ChargeMin = 0.5,
    ChargeMax = 1.5,
  },
}

-- Skills tuning
CombatConfig.Skill = {
  BaseHpDamage = 8,
  BaseGuardDamage = 12,
}

-- Equipment quality influence (0-100)
CombatConfig.Quality = {
  DamageMultiplierPerPoint = 0.002, -- per quality point
  GuardMultiplierPerPoint = 0.002,
  ParryWindowPerPoint = 0.0005,
}

-- Stat scaling
CombatConfig.StatMultipliers = {
  Strength = 0.01,
  Agility = 0.01,
  Mana = 0.01,
}

-- Export
return CombatConfig