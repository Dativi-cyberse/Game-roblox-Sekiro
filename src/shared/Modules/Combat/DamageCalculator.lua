local DamageCalculator = {}

function DamageCalculator.Calculate(attackerState, baseDamage, defenderState, isCritical)
    local multiplier = isCritical and 2 or 1
    local totalDamage = baseDamage * multiplier

    local shieldDamage = math.min(defenderState.Shield, totalDamage)
    local hpDamage = math.max(0, totalDamage - shieldDamage)

    return shieldDamage, hpDamage
end

return DamageCalculator
