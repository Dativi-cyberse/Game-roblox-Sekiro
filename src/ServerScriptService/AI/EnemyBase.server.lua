local EnemyBase = {}

function EnemyBase.new(template)
    local self = {}
    self.MaxHP = template.MaxHP or 100
    self.HP = self.MaxHP
    self.MaxShield = template.MaxShield or 30
    self.Shield = self.MaxShield
    self.Stamina = template.MaxStamina or 60
    self.MaxStamina = template.MaxStamina or 60
    self.State = "Idle"

    function self:IsDead()
        return self.HP <= 0
    end

    return self
end

return EnemyBase
