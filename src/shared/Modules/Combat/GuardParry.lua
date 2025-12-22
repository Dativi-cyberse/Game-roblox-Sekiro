local GuardParry = {}

function GuardParry.IsParryActive(playerState)
    return playerState.ParryWindow
end

return GuardParry
