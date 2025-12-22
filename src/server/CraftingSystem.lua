-- CraftingSystem.lua
-- Loot, mining, and crafting system for generating gear with quality ranges.

local CraftingSystem = {}

-- Loot table: returns a weapon name and a quality (10-50%) for NPC drops
function CraftingSystem.RollLootWeapon()
    local weapons = { "DualDaggers", "Longsword", "MagicStaff" }
    local choice = weapons[math.random(#weapons)]
    local quality = math.random(10, 50) / 100
    return choice, quality
end

-- Crafting: consumes materials (not modelled here) and produces higher quality gear (60-100%)
-- materials param is a table; server must validate materials before calling
function CraftingSystem.CraftWeapon()
    -- simple validation stub: assume materials valid
    return math.random(60, 100) / 100
end

-- Stat scaling: higher quality increases armor and parry window bonus (returns multipliers)
function CraftingSystem.QualityToStats(quality)
    quality = math.clamp and math.clamp(quality, 0.01, 1) or (quality < 0.01 and 0.01 or (quality > 1 and 1 or quality))
    local armorBonus = 1 + (quality - 0.5) * 0.4 -- example: quality 1.0 -> +20% armor
    local parryWindowBonus = 1 + (quality - 0.5) * 0.2
    return armorBonus, parryWindowBonus
end

return CraftingSystem
