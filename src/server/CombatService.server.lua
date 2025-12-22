-- CombatService.server.lua
-- Server-authoritative combat logic
-- Fully compatible with PlayerState FINAL-CLEAN
print("CombatServer running")

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Modules
local Constants = require(ReplicatedStorage.Modules.Core.Constants)
local PlayerState = require(ReplicatedStorage.Modules.Core.PlayerState)
local WeaponData = require(ReplicatedStorage.Modules.Weapons.WeaponData)
local DamageCalculator = require(ReplicatedStorage.Modules.Combat.DamageCalculator)
local GuardParry = require(ReplicatedStorage.Modules.Combat.GuardParry)
local ClashResolver = require(ReplicatedStorage.Modules.Combat.ClashResolver)
local ShieldSystem = require(ReplicatedStorage.Modules.Combat.ShieldSystem)
local Hitbox = require(ReplicatedStorage.Modules.Combat.Hitbox)
local SprintModule = require(ReplicatedStorage.Modules.Movement.Sprint)
local TargetValidator = require(ReplicatedStorage.Modules.Targeting.TargetValidator)

-- Remotes
local Remotes = ReplicatedStorage
    :WaitForChild("Shared")
    :WaitForChild("Remotes")

local CombatRemotes = Remotes:WaitForChild("Combat")

local M1Event = CombatRemotes:WaitForChild("M1Event")
local GuardEvent = CombatRemotes:WaitForChild("GuardEvent")
local SprintEvent = CombatRemotes:WaitForChild("SprintEvent")
local TargetLockEvent = CombatRemotes:WaitForChild("TargetLockEvent")
local ClashEvent = CombatRemotes:FindFirstChild("ClashEvent") -- optional remote
local CombatService = {}

local function getWeaponData(weapon)
    if not weapon then return nil end
    local weaponType = weapon:GetAttribute("WeaponType")
    return WeaponData[weaponType]
end 

local function getBaseDamage(weapon)
    local weaponData = getWeaponData(weapon)
    return weaponData and weaponData.BaseDamage or Constants.Attack.BaseDamage
end 

local function getStaminaCost(weapon)
    local weaponData = getWeaponData(weapon)
    return weaponData and weaponData.StaminaCost or Constants.Attack.StaminaCost
end 

local function getHitboxSize(weapon)
    local weaponData = getWeaponData(weapon)
    return weaponData and weaponData.HitboxSize or Constants.Attack.HitboxSize
end 

local function getHitboxOffset(weapon)
    local weaponData = getWeaponData(weapon)
    return weaponData and weaponData.HitboxOffset or Constants.Attack.HitboxOffset
end 

local function getHitboxLifetime(weapon)
    local weaponData = getWeaponData(weapon)
    return weaponData and weaponData.HitboxLifetime or Constants.Attack.HitboxLifetime
end 

local function getHitboxCooldown(weapon)
    local weaponData = getWeaponData(weapon)
    return weaponData and weaponData.HitboxCooldown or Constants.Attack.HitboxCooldown
end 

local function getHitboxCooldown(weapon)
    local weaponData = getWeaponData(weapon)
    return weaponData and weaponData.HitboxCooldown or Constants.Attack.HitboxCooldown
end 

local function getHitboxCooldown(weapon)
    local weaponData = getWeaponData(weapon)
    return weaponData and weaponData.HitboxCooldown or Constants.Attack.HitboxCooldown
end 

local function getHitboxCooldown(weapon)
    local weaponData = getWeaponData(weapon)
    return weaponData and weaponData.HitboxCooldown or Constants.Attack.HitboxCooldown
end 

local function getHitboxCooldown(weapon)
    local weaponData = getWeaponData(weapon)
    return weaponData and weaponData.HitboxCooldown or Constants.Attack.HitboxCooldown
end 

local function getHitboxCooldown(weapon)
    local weaponData = getWeaponData(weapon)
    return weaponData and weaponData.HitboxCooldown or Constants.Attack.HitboxCooldown
end 

local function getHitboxCooldown(weapon)
    local weaponData = getWeaponData(weapon)
    return weaponData and weaponData.HitboxCooldown or Constants.Attack.HitboxCooldown
end

-- =====================================================
-- PLAYER STATE STORAGE
-- =====================================================
local PlayerStates = {}

local function getState(player)
    local ps = PlayerStates[player]
    if not ps then
        ps = PlayerState.new()      
        PlayerStates[player] = ps
    end
    return ps
end

-- =====================================================
-- VALIDATION
-- =====================================================
local function canAct(player)
    local ps = PlayerStates[player]
    if not ps then return false end
    if ps:IsDead() then return false end
    if ps.IsStunned or ps.IsGuardBroken then return false end
    return true
end

-- =====================================================
-- M1 ATTACK
-- =====================================================
local function onM1(player, payload)
    if not canAct(player) then return end
    if type(payload) ~= "table" then return end

    local ps = getState(player)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- stamina cost
    if ps.Stamina < Constants.Attack.StaminaCost then return end
    ps:DrainStamina(Constants.Attack.StaminaCost)
    ps:SetAttacking(true)

    -- charge
    local press = payload.press or 0
    local release = payload.release or press
    local holdTime = math.max(0, release - press)

    local isCharge = holdTime >= Constants.Attack.Charge.Min
    local chargeMul = isCharge
        and math.clamp(holdTime / Constants.Attack.Charge.Max, 0, 1)
        or 1

    -- weapon
    local weaponKey = payload.weapon or "Sword"
    local weapon = WeaponData[weaponKey] or WeaponData.Sword
    local baseDamage = weapon.Damage * chargeMul

    -- hit detection
    local origin = hrp.Position + Vector3.new(0, 2, 0)
    local direction = hrp.CFrame.LookVector
    local hit = Hitbox.Raycast(origin, direction, weapon.Range, { char })

    if hit and hit.Instance then
        local targetChar = hit.Instance:FindFirstAncestorOfClass("Model")
        local targetPlayer = Players:GetPlayerFromCharacter(targetChar)

        if targetPlayer then
            local tps = getState(targetPlayer)

            -- CLASH
            if ClashResolver.Check(ps, tps) then
                ps:ApplyStun(0.4)
                tps:ApplyStun(0.4)

                if ClashEvent then
                    ClashEvent:FireAllClients(hrp.Position)
                end
                return
            end

            -- PARRY
            if tps.IsParryWindowActive then
                ps:ApplyStun(0.5)
                tps:EnableCriticalWindow(1.0)
                return
            end

            -- DAMAGE CALC
            local shieldDmg, hpDmg =
                DamageCalculator.Calculate(ps, baseDamage, tps, tps.CanCriticalStrike)

            if shieldDmg > 0 then
                ShieldSystem.ApplyGuardDamage(tps, shieldDmg)
            end
            if hpDmg > 0 then
                tps:TakeHP(hpDmg)
            end
        end
    end

    -- end attack
    task.delay(Constants.Attack.RecoverTime or 0.2, function()
        ps:SetAttacking(false)
    end)
end

-- =====================================================
-- GUARD / PARRY
-- =====================================================
local function onGuard(player, info)
    if type(info) ~= "table" then return end
    local ps = getState(player)

    if info.action == "start" then
        if not canAct(player) then return end
        ps:OpenParryWindow()
    elseif info.action == "stop" then
        ps.IsParryWindowActive = false
    end
end

-- =====================================================
-- SPRINT
-- =====================================================
local function onSprint(player, action)
    local ps = getState(player)

    if action == "start" then
        if not canAct(player) then return end
        if ps.Stamina <= 0 then return end

        ps:SetSprinting(true)
        SprintModule.Start(player)

    elseif action == "stop" then
        ps:SetSprinting(false)
        SprintModule.Stop(player)
    end
end

-- =====================================================
-- TARGET LOCK
-- =====================================================
local function onTargetLock(player, target)
    if target and TargetValidator.IsValidTarget(player, target, Constants.Targeting.MaxLockDistance) then
        player:SetAttribute("CurrentTarget", target:GetDebugId())
    else
        player:SetAttribute("CurrentTarget", "")
    end
end

-- =====================================================
-- SERVER TICK LOOP
-- =====================================================
RunService.Heartbeat:Connect(function(dt)
    if next(PlayerStates) == nil then return end

    for _, ps in pairs(PlayerStates) do
        ps:Tick(dt)
    end
end)

-- =====================================================
-- PLAYER LIFECYCLE
-- =====================================================
Players.PlayerAdded:Connect(function(player)
    PlayerStates[player] = PlayerState.new()
end)

Players.PlayerRemoving:Connect(function(player)
    PlayerStates[player] = nil
    SprintModule.Stop(player)
end)

-- =====================================================
-- REMOTES
-- =====================================================
M1Event.OnServerEvent:Connect(onM1)
GuardEvent.OnServerEvent:Connect(onGuard)
SprintEvent.OnServerEvent:Connect(onSprint)
TargetLockEvent.OnServerEvent:Connect(onTargetLock)

return CombatService
