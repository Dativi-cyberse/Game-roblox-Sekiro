# Client-Side Character Combat System

## Overview

A modular, Sekiro-inspired combat system for client-side character control in Roblox. All scripts are placed in `StarterPlayer/StarterCharacterScripts`.

## Architecture

### Core Modules

1. **StateMachine.lua** - Pure state transition logic
   - States: Idle, Attacking, Blocking, Parrying, Stunned, Dashing, Dead
   - Explicit transition rules prevent illegal actions
   - State change signals for integration

2. **CombatController.lua** - M1 Combo System
   - Sequential combo chain (configurable max hits)
   - Combo resets on timeout or interruption
   - Combo index advances automatically

3. **PostureController.lua** - Posture Management
   - Posture value (0 → max)
   - Increases when blocking/getting parried
   - Breaks when full → triggers stunned state
   - Gradual regeneration when idle

4. **ParryController.lua** - Parry Timing Logic
   - Small timing window (default 0.2s)
   - Success/failure callbacks
   - Cooldown system

5. **DashController.lua** - Dash/Step Dodge
   - Directional movement (WASD-based)
   - Configurable speed, duration, cooldown
   - Velocity tracking

6. **AnimationController.lua** - Abstract Animation System
   - No hardcoded animation IDs
   - Slot-based system (e.g., "Attack1", "Block", "Parry")
   - Ready for animation injection
   - Handles animation priority and fading

7. **CharacterController.client.lua** - Main Orchestrator
   - Initializes all controllers
   - Handles input (M1, M2, Space/Shift)
   - Coordinates system interactions
   - Manages lifecycle (respawn, death cleanup)

## Input System

- **M1 (Left Click)**: Attack
  - Triggers combo chain
  - Applies posture cost
  - Can only attack from Idle or Dashing states

- **M2 (Right Click)**: Block/Parry
  - Hold < 0.2s = Parry attempt
  - Hold > 0.2s = Block
  - Quick tap = Parry

- **Space/Shift**: Dash
  - Directional based on WASD movement
  - Uses camera-relative direction
  - Can cancel attacks

## State Flow

### Attack Flow
1. Player presses M1
2. Check if `CanAttack()` (Idle or Dashing state)
3. `CombatController:AttemptAttack()` - checks cooldown
4. Transition to Attacking state
5. Play animation from slot "Attack" + comboIndex
6. On animation end → return to Idle
7. Advance combo index for next attack

### Parry Flow
1. Player quickly taps M2 (< 0.2s)
2. Transition to Parrying state
3. `ParryController:AttemptParry()` - records timestamp
4. Play "Parry" animation
5. After 0.2s → return to Idle
6. Server validates timing when attack arrives

### Block Flow
1. Player holds M2 (> 0.2s)
2. Transition to Blocking state
3. Play "Block" animation
4. On release → return to Idle
5. Posture increases when blocking attacks

### Dash Flow
1. Player presses Space/Shift while moving
2. Check if `CanDash()` (Idle or Attacking state)
3. Calculate direction from camera + movement keys
4. `DashController:AttemptDash()` - checks cooldown
5. Transition to Dashing state
6. Apply dash velocity via BodyVelocity
7. After dash duration → return to Idle

### Posture Break Flow
1. Posture reaches max value
2. `PostureController` fires `OnPostureBroken` signal
3. Transition to Stunned state
4. Play "Stunned" animation
5. After 1.5s → reset posture, return to Idle

## Animation Integration

Animations are loaded via slots. To inject animations:

```lua
local animationController = controllers.animation
local animator = humanoid:FindFirstChildOfClass("Animator")

-- Load animation from module or asset
local attack1Anim = Instance.new("Animation")
attack1Anim.AnimationId = "rbxassetid://..."
local track = animator:LoadAnimation(attack1Anim)

-- Set slot
animationController:SetAnimationSlot("Attack1", track)
```

Expected animation slots:
- `Attack1`, `Attack2`, `Attack3`, `Attack4`, `Attack5` (combo chain)
- `Block`
- `Parry`
- `Dash`
- `Stunned`

## Configuration

All controllers accept configuration in their constructors:

```lua
-- Posture
PostureController.new(maxPosture, recoveryRate, recoveryDelay)

-- Parry
ParryController.new(parryWindow, cooldown)

-- Dash
DashController.new(dashSpeed, dashDuration, dashCooldown)

-- Combat
CombatController.new(maxCombo, comboResetTime, attackCooldown)
```

## Respawn Safety

- All connections are tracked and cleaned up on death
- Controllers are reset on respawn
- BodyVelocity is properly cleaned up
- State machine resets to Idle
- Animations are stopped

## Server Integration (Future)

This system is designed to work with server-side RemoteEvents:

- Client sends attack intent → Server validates and processes
- Client sends parry intent → Server checks timing window
- Client sends block state → Server applies damage reduction
- Server sends posture damage → Client updates posture
- Server sends state changes → Client updates state machine

## Extensibility

The modular design allows easy extension:

- Add new states to `StateMachine`
- Add new animation slots to `AnimationController`
- Add new combat actions to `CombatController`
- Integrate with server damage system
- Add visual/audio feedback via controller signals

