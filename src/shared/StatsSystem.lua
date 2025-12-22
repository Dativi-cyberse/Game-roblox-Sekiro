-- StatsSystem.lua
-- Simple skill tree system for Strength, Agility, Mana with level-up via skill points.

local StatsSystem = {}

local DEFAULTS = {
    Strength = 1,
    Agility = 1,
    Mana = 1,
}

function StatsSystem.New(playerId, opts)
    opts = opts or {}
    local s = {}
    s.PlayerId = playerId
    s.Level = opts.Level or 1
    s.SkillPoints = opts.SkillPoints or 0
    s.Strength = opts.Strength or DEFAULTS.Strength
    s.Agility = opts.Agility or DEFAULTS.Agility
    s.Mana = opts.Mana or DEFAULTS.Mana
    return s
end

function StatsSystem.LevelUp(stats, attr)
    if not stats or stats.SkillPoints <= 0 then return false end
    if attr ~= "Strength" and attr ~= "Agility" and attr ~= "Mana" then return false end
    stats.SkillPoints = stats.SkillPoints - 1
    stats[attr] = stats[attr] + 1
    return true
end

-- Apply stat effects helpers
function StatsSystem.GetDamageMultiplier(stats, weaponType)
    local mult = 1
    if weaponType == "DualDaggers" or weaponType == "Longsword" or weaponType == "Sword" then
        mult = mult + (stats.Strength or 0) * 0.01
    end
    return mult
end

function StatsSystem.GetStaminaRegenBonus(stats)
    return (stats.Agility or 0) * 0.01
end

function StatsSystem.GetMaxMana(stats)
    return 50 + (stats.Mana or 0) * 10
end

return StatsSystem
