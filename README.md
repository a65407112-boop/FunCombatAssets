# FunCombatAssets — authoritative rebuild

This repository was reset on 2026-08-27. The old Lua-serialized runtime (`core.lua`, `data/*.lua`, `loader_*`, UI hotfixes) has been removed.

## New architecture

The Roblox place is self-contained and does **not** execute gameplay from GitHub.

- Server owns weapon issuance, hitboxes, combo order, damage, dash movement, ragdoll/downed, carry/execute, gender state and validation.
- Client only handles input and presentation.
- Animations/models are preserved as native Roblox RBXM assets rather than rewritten into Lua tables.
- `Gender` is again the real player attribute and is rendered by the server-owned overhead Info billboard.
- Weapon selection requests `EquipWeapon`; the server clones only allow-listed tools into Backpack.
- Client attack input sends only move IDs (`SWING_1`, `SWING_2`, `BIG_SWING`). The server computes the hitbox and victims itself.

`manifest.json` and `validation.json` list the rebuilt RBXM asset packs and SHA-256 hashes. Server-source RBXM backups are deliberately not published here.

The deployable place build is `FunCombat_Authoritative_Rebuild.rbxl`.
