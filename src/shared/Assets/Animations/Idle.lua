-- ModuleScript: Idle
-- Rojo path: ReplicatedStorage/Assets/Animations/Idle
-- This module only supplies the AnimationId and priority for the built-in
-- Roblox Animate system. A LocalScript in StarterCharacterScripts will apply
-- this id into the runtime `Animate` script so the Animate system controls
-- idle playback (per the architecture rules).

local module = {}
module.Id = "rbxassetid://92623070036603"
module.Priority = Enum.AnimationPriority.Idle
return module
