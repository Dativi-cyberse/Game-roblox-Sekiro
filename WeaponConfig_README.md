WeaponConfig example
====================

This project reads weapon configuration from ReplicatedStorage (Folder + ValueObjects or Attributes).
This README explains the example structure and how to create it quickly.

Location:
- ReplicatedStorage/WeaponConfig/<WeaponName>

Supported fields (ValueObjects or Attributes):
- ComboCount (NumberValue): number of combo steps
- ComboTimeout (NumberValue): seconds allowed between clicks to continue combo
- Combo1, Combo2, ... (StringValue): animation id (string or plain numeric id) for each combo step
- AttackAnimation (StringValue): fallback animation id
- Damage (NumberValue): base damage
- Damage1, Damage2, ... (NumberValue): per-step damage override
- GuardDamage (NumberValue): base guard damage
- GuardDamage1, ... (NumberValue): per-step guard damage override

Quick way to create the example in Studio:
1. Place `src/server/MakeWeaponConfigExample.lua` under `ServerScriptService` or run it from the command bar.
2. It will create `ReplicatedStorage/WeaponConfig/Sword` with ValueObjects and placeholder animation ids.

Notes:
- Do NOT convert configs into ModuleScripts — the code intentionally reads ValueObjects/Attributes.
- Replace placeholder animation ids in the created folder with your published animation asset ids.
