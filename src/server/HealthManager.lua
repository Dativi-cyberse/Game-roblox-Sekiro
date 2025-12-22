-- HealthManager.lua
-- Manage NPC/Boss health and shield (guard) bars, guard break, and executions.

local HealthManager = {}

-- Create an entity state wrapper (not a Roblox Instance)
function HealthManager.NewEntity(opts)
    opts = opts or {}
    local ent = {}
    ent.MaxHealth = opts.MaxHealth or 100
    ent.Health = opts.Health or ent.MaxHealth
    ent.MaxShield = opts.MaxShield or 50
    ent.Shield = opts.Shield or ent.MaxShield
    ent.IsBoss = opts.IsBoss or false
    ent._brokenUntil = 0
    ent._stunnedUntil = 0
    return ent
end

local function clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

-- Apply shield (guard) damage; returns table { shieldBroken = bool }
function HealthManager.ApplyShieldDamage(entity, amount)
    if not entity then return { shieldBroken = false } end
    amount = amount or 0
    local before = entity.Shield
    entity.Shield = clamp(entity.Shield - amount, 0, entity.MaxShield)
    if before > 0 and entity.Shield <= 0 then
        entity._brokenUntil = os.clock() + 1.0 -- exactly 1 second broken
        return { shieldBroken = true }
    end
    return { shieldBroken = false }
end

-- Apply HP damage (does not bypass shield logic)
function HealthManager.ApplyDamage(entity, amount)
    if not entity then return { killed = false } end
    amount = amount or 0
    entity.Health = clamp(entity.Health - amount, 0, entity.MaxHealth)
    local killed = entity.Health <= 0
    return { killed = killed, newHealth = entity.Health }
end

-- Attempt execution during broken window
-- attacker performs stab; damage capped by boss/normal rules
function HealthManager.TryExecute(attacker, entity, baseDamage)
    if not entity then return { executed = false, reason = "invalid" } end
    if os.clock() > (entity._brokenUntil or 0) then
        return { executed = false, reason = "no_window" }
    end

    local cap = entity.IsBoss and (entity.MaxHealth * 0.2) or (entity.MaxHealth * 0.66)
    local dmg = math.min(baseDamage or 0, cap)
    local res = HealthManager.ApplyDamage(entity, dmg)
    -- consume window
    entity._brokenUntil = 0
    return { executed = true, damage = dmg, result = res }
end

-- Parry interaction: if NPC is parried, stunned for 0.5s and take direct shield damage
function HealthManager.OnParried(entity, shieldDamage)
    if not entity then return end
    entity._stunnedUntil = os.clock() + 0.5
    HealthManager.ApplyShieldDamage(entity, shieldDamage or 0)
end

-- Utility: check if entity is broken
function HealthManager.IsBroken(entity)
    return os.clock() <= (entity._brokenUntil or 0)
end

-- Utility: check if entity stunned
function HealthManager.IsStunned(entity)
    return os.clock() <= (entity._stunnedUntil or 0)
end

return HealthManager
