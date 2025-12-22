local ClashResolver = {}

function ClashResolver.Check(attackerState, defenderState)
    return attackerState.IsAttacking and defenderState.IsAttacking
end

return ClashResolver
