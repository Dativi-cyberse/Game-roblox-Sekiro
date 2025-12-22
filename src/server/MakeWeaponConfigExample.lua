-- MakeWeaponConfigExample.lua
-- Run this script in Roblox Studio (ServerScriptService or command bar) to create
-- a sample `ReplicatedStorage/WeaponConfig/Sword` folder with ValueObjects and Attributes
-- for testing combo animations and damage values. This is not required at runtime;
-- it's a convenience helper for local testing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Only run in Studio to avoid accidental execution on live servers
if not RunService:IsStudio() then
    warn("MakeWeaponConfigExample: intended for Studio only")
    return
end

local ROOT_NAME = "WeaponConfig" -- script and client/server code accept WeaponConfig/Weapons/WeaponConfigs
local WEAPON_NAME = "Sword"

local function ensureFolder(pathParent, name)
    local f = pathParent:FindFirstChild(name)
    if f and f:IsA("Folder") then return f end
    f = Instance.new("Folder")
    f.Name = name
    f.Parent = pathParent
    return f
end

local function makeNumber(parent, name, value)
    local existing = parent:FindFirstChild(name)
    if existing and existing:IsA("NumberValue") then
        existing.Value = value
        return existing
    end
    local nv = Instance.new("NumberValue")
    nv.Name = name
    nv.Value = value
    nv.Parent = parent
    return nv
end

local function makeString(parent, name, value)
    local existing = parent:FindFirstChild(name)
    if existing and existing:IsA("StringValue") then
        existing.Value = value
        return existing
    end
    local sv = Instance.new("StringValue")
    sv.Name = name
    sv.Value = value
    sv.Parent = parent
    return sv
end

local root = ReplicatedStorage:FindFirstChild(ROOT_NAME) or Instance.new("Folder")
if not root.Parent then
    root.Name = ROOT_NAME
    root.Parent = ReplicatedStorage
end

local sword = ensureFolder(root, WEAPON_NAME)

-- Example values (replace animation ids with your published animation asset ids)
makeNumber(sword, "ComboCount", 3)
makeNumber(sword, "ComboTimeout", 0.8)
makeNumber(sword, "Damage", 10)
makeNumber(sword, "Damage1", 8)
makeNumber(sword, "Damage2", 12)
makeNumber(sword, "Damage3", 18)
makeNumber(sword, "GuardDamage", 5)
makeNumber(sword, "GuardDamage1", 4)
makeNumber(sword, "GuardDamage2", 6)
makeNumber(sword, "GuardDamage3", 8)

-- Replace these with your animation asset ids (string or numeric id). Examples below are placeholders.
makeString(sword, "Combo1", "12345678")
makeString(sword, "Combo2", "23456789")
makeString(sword, "Combo3", "34567890")
makeString(sword, "AttackAnimation", "12345678")

print("MakeWeaponConfigExample: created/updated ReplicatedStorage/"..ROOT_NAME.."/"..WEAPON_NAME)
