
local WeaponData = {
    Damage = 25,
    Cooldown = 0.5,
    Animations = {
        Slash = "rbxassetid://127964771902906"
    }
}
-- Utility to clamp values
local function clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

-- Quality: 0.1 to 1.0 multiplies damage/guard/parry frames
local function qualityMultiplier(quality)
    return clamp(quality or 0.5, 0.1, 1.0)
end

WeaponData.DualDaggers = {
    Type = "DualDaggers",
    BaseDamage = 6,        -- per hit
    GuardDamage = 7,       -- per hit
    Range = 3.2,
    AttackSpeed = 1.8,
    HitsPerClick = 2,
    ChargeRequired = 0,    -- not used
    ChargeMultiplier = 1.0,
    -- Quality affects damage/guard/parry window externally
}

WeaponData.Longsword = {
    Type = "Longsword",
    BaseDamage = 12,
    GuardDamage = 14,
    Range = 5.5,
    AttackSpeed = 1.0,
    HitsPerClick = 1,
    ChargeRequired = 0,
    ChargeMultiplier = 1.0,
}

WeaponData.MagicStaff = {
    Type = "MagicStaff",
    BaseDamage = 18,
    GuardDamage = 10,
    Range = 8.0,
    AttackSpeed = 0.7,
    HitsPerClick = 1,
    ChargeRequired = 0.5,
    ChargeMax = 1.5,
    ChargeMultiplier = 1.8,
}

function WeaponData.CalculateDamage(entry, quality, holdTime)
    quality = quality or 0.5
    local q = qualityMultiplier(quality)
    local base = entry.BaseDamage * q
    if entry.Type == "MagicStaff" and holdTime and holdTime >= (entry.ChargeRequired or 0) then
        local clamped = math.min(holdTime, entry.ChargeMax or entry.ChargeRequired)
        local factor = 0.5 + (clamped - (entry.ChargeRequired or 0)) / ((entry.ChargeMax or entry.ChargeRequired) - (entry.ChargeRequired or 0) + 1e-6) * (entry.ChargeMultiplier - 0.5)
        return base * factor, entry.GuardDamage * q
    end
    return base, entry.GuardDamage * q
end

return WeaponData
