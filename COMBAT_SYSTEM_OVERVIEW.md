# Sekiro-Style Combat System Overview

## Architecture

### Core Modules (ReplicatedStorage/Shared/Modules/Combat)
- **PostureService**: Manages posture damage, regeneration, and break detection
- **ParryService**: Handles parry timing windows and validation
- **DamageService**: Calculates health and posture damage based on context
- **HitboxService**: Animation-driven hit detection (no always-on hitboxes)

### Server Services (ServerScriptService/Services)
- **CombatService.server.lua**: Authoritative combat orchestrator
- **CombatRemoteHandler.server.lua**: Handles RemoteEvent connections

### Client Scripts
- **InputController.client.lua**: Captures input and sends intents
- **CombatClient.client.lua**: Handles input via FSM and manages animations through AnimationController
- **AnimationController.lua**: Plays animations and handles marker events for hit detection

## Combat Flow

### 1. Attack Flow
1. **Client**: Player presses M1 → `CombatClient` handles input via FSM
2. **Client**: `AnimationController` plays attack animation
3. **Client**: Animation reaches `HitStart` marker → fires `Attack` RemoteEvent
4. **Server**: `CombatRemoteHandler` receives attack → calls `CombatService.ProcessAttack`
5. **Server**: Creates temporary hitbox in front of attacker
6. **Server**: Detects targets within hitbox
7. **Server**: For each target:
   - Checks if parry succeeded (timing window validation)
   - If parried: Apply large posture damage to attacker
   - If blocked: Reduce health damage, apply posture damage
   - If hit: Apply full damage
8. **Server**: Applies posture cost to attacker for attacking
9. **Server**: Returns to idle state

### 2. Parry Flow
1. **Client**: Player quickly taps M2 (hold < 0.2s)
2. **Client**: `InputController` sends `Parry` RemoteEvent
3. **Server**: `ParryService.RecordParryIntent` stores timestamp
4. **Server**: When attack arrives, `ParryService.ResolveParry` checks timing window
5. **Server**: If within window: Success → large posture damage to attacker
6. **Server**: If outside window: Failed → penalty to defender

### 3. Block Flow
1. **Client**: Player holds M2 (> 0.2s)
2. **Client**: `InputController` sends `Block` RemoteEvent with action="start"
3. **Server**: Character enters `Blocking` state
4. **Server**: When attacked: Health damage reduced by 70%, posture damage still applies
5. **Client**: Player releases M2 → action="stop"
6. **Server**: Character returns to `Idle` state

### 4. Posture System
- **Posture increases** when:
  - Attacking
  - Getting parried
  - Blocking attacks
- **Posture regenerates** slowly when not in combat (after 0.5s delay)
- **Posture breaks** when posture >= MaxPosture → character enters stagger state

### 5. Deathblow Flow
1. **Server**: Target's posture is broken
2. **Client**: Player sees deathblow prompt (F key)
3. **Client**: Player presses F → sends `Deathblow` RemoteEvent
4. **Server**: Validates target posture is broken and range is valid
5. **Server**: Locks both characters (Deathblow state)
6. **Server**: Kills target instantly
7. **Server**: Unlocks after animation duration (2.5s)

## Animation Markers

Animations must include these markers:
- **HitStart**: When hit detection window begins → triggers server attack
- **HitEnd**: When hit detection window ends (optional, for cleanup)
- **ParryWindow**: Visual feedback marker (optional)

## State Machine

Character states:
- **Idle**: Default state, can perform any action
- **Attacking**: Executing attack animation
- **Blocking**: Holding block
- **Staggered**: Posture broken, cannot act
- **Deathblow**: Executing deathblow (locked)
- **DeathblowVictim**: Being deathblown (locked)

## Key Design Decisions

1. **Server-Authoritative**: All damage, posture, and state changes happen server-side
2. **Animation-Driven**: Hit detection only during animation marker windows
3. **Timing-Based Parry**: Parry is a quick tap, not hold
4. **Posture-Focused**: Posture break is the primary win condition
5. **Exploit Prevention**: Cooldowns, range validation, state checks on server

## Future Expansions

- Perilous attacks (unblockable, requires dodge)
- Skills system
- Boss-specific mechanics
- Combo system refinements


