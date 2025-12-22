local EnemyBase = require(script.Parent.EnemyBase)

local Dummy = {}

function Dummy.Spawn(position)
    local data = EnemyBase.new({MaxHP=80, MaxShield=20, MaxStamina=40})
    data.Position = position
    -- placeholder: in-studio this module should hook into a model and humanoid
    return data
end

return Dummy
