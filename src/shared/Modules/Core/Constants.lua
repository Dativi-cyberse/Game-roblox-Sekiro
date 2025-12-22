local Constants = {}

-- Tunable values for combat system
Constants.DEBUG = false

-- Parry / guard
Constants.PARRY_WINDOW = 0.15 -- seconds accepted as perfect parry window
Constants.PARRY_GRACE = 0.04 -- extra server-side tolerance
Constants.FAILED_PARRY_POSTURE_PENALTY = 8

-- Posture
Constants.POSTURE_MAX = 100
Constants.POSTURE_RECOVERY_RATE = 6 -- per second when not in combat
Constants.POSTURE_DAMAGE_MULTIPLIER = 1.0

-- Damage multipliers
Constants.BASE_DAMAGE_MULTIPLIER = 1.0
Constants.GUARD_POSTURE_REDUCTION = 0.5 -- posture damage multiplier when guarding
Constants.GUARD_HP_REDUCTION = 0.6 -- hp damage multiplier when guarding

-- Guard / Stamina
Constants.GUARD_STAMINA_DRAIN_PER_SECOND = 12
Constants.GUARD_POSTURE_DRAIN_PER_SECOND = 6
Constants.MIN_STAMINA_TO_GUARD = 1

-- Sprint
Constants.SPRINT_STAMINA_DRAIN_PER_SECOND = 18

-- Targeting
Constants.LOCKON_MAX_DISTANCE = 60
Constants.LOCKON_MAX_ANGLE = math.rad(60)

-- Clash resolution
Constants.CLASH_TOLERANCE = 0.06 -- seconds for considering simultaneous hits

return Constants
