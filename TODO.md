# Combat System Animation Fixes

## Issues Identified
- Animation loading fails without pcall, causing client crashes.
- Inconsistent property names in animation modules (Id vs AnimationId).
- Default Animate script not destroyed on character spawn.
- ModuleScripts must return exactly one value (already compliant).

## Plan
1. Fix animation module property names: Change code to use `animModule.Id` instead of `animModule.AnimationId`.
2. Wrap `LoadAnimation` in `pcall` in AnimationController.lua: If fails, warn and skip loading that animation.
3. Wrap `LoadAnimation` in `pcall` in M1.client.lua: If fails, warn, skip animation, but continue attack logic (fire server event).
4. Wrap `LoadAnimation` in `pcall` in Sword.client.lua: Same as M1.client.lua.
5. Destroy default Animate script in CombatClient.lua on character spawn.
6. Ensure combat flow continues even with zero animations loaded.

## Files to Edit
- src/shared/Assets/Animations/Slash1.lua (and others if needed, but consistent)
- src/StarterPlayer/StarterCharacterScripts/AnimationController.lua
- src/StarterPack/Sword/M1.client.lua
- src/StarterPack/EpicKatana/Sword.client.lua
- src/StarterPlayer/StarterCharacterScripts/CombatClient.client.lua

## Followup Steps
- Test animation loading with invalid IDs.
- Verify combat input works without animations.
- Ensure no infinite loops or stuck states.
