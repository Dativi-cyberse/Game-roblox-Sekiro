local TargetValidator = {}

function TargetValidator.IsValidTarget(player, target, maxDistance)
    if not target:IsA("Model") then
        return false
    end

    local humanoid = target:FindFirstChild("Humanoid")
    if not humanoid then
        return false
    end

    local playerCharacter = player.Character
    if not playerCharacter then
        return false
    end

    local playerRoot = playerCharacter:FindFirstChild("HumanoidRootPart")
    local targetRoot = target:FindFirstChild("HumanoidRootPart")
    if not playerRoot or not targetRoot then
        return false
    end

    local distance = (playerRoot.Position - targetRoot.Position).Magnitude
    return distance <= maxDistance
end

return TargetValidator
