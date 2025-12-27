# FSM Fix TODO

- [x] Add context.previousMoveMagnitude = 0 in CombatClient.client.lua
- [x] Modify IdleState.lua:Update to edge-triggered Move transition (0 to >0)
- [x] Modify MoveState.lua:Update to edge-triggered Idle transition (>0 to 0)
- [x] Verify BlockState.lua:Enter has early return if not weaponEquipped
- [x] Test FSM transitions for no Idle ↔ Block looping
