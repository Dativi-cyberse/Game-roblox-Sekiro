local WeaponData = {}

-- Normalize weapon table to ensure expected fields exist.
-- Accepts a table with optional fields and returns sanitized weapon info.
function WeaponData.Normalize(data)
	data = data or {}
	local out = {}
	out.id = data.id or "generic"
	out.name = data.name or "Generic Sword"
	out.baseDamage = data.baseDamage or 12
	out.postureDamage = data.postureDamage or math.max(1, math.floor(out.baseDamage * 0.6))
	out.range = data.range or 4
	out.speed = data.speed or 1.0 -- attack speed multiplier
	out.guardMultiplier = data.guardMultiplier or 0.6 -- damage multiplier when blocked
	out.critMultiplier = data.critMultiplier or 1.0
	out.tags = data.tags or {}
	return out
end

return WeaponData
