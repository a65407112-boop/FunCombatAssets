# FunCombatAssets — server-only map/prompts rebuild

The old Lua-serialized runtime (`core.lua`, `data/*.lua`, `loader_*`, UI hotfixes) is gone.

## Final architecture

The published Roblox place contains the physical world/map, ProximityPrompts, replicated networking endpoints, and hidden server gameplay code.

- `StarterGui` is empty.
- `StarterPlayer` contains no client scripts.
- No LocalScripts are shipped in the server place.
- Full animations, morphs, VFX, sounds, weapon visuals and GUI are client RBXM assets.
- Gameplay modules are hidden in ServerStorage under opaque names.
- ReplicatedStorage exposes only opaque Remotes/RemoteEvents, prompt templates, and the Gender SetInfo endpoint.
- Client attacks send only an allow-listed move ID. The server validates combo/cooldown and computes victims with `workspace:GetPartBoundsInBox`.
- Damage, ragdoll/downed, carry/execute, Gender, emote permission, killstreak/awaken and player interaction remain server-authoritative.

Deployable server build: `FunCombat_ServerOnly_MapPrompts_EXECUTE_FIX.rbxl`.

The build uses compact Roblox binary IDs: all 6,752 instance referents are remapped to `0..6751`, class IDs are compact, PRNT links are remapped, and Object-reference properties are remapped/nullified when their target is outside the thin build.

The execute/get-up interaction fix also removes the stale clear `ReplicatedStorage.Remotes.Ragdoll` lookup from the server Ragdoll module. It now uses the opaque server network path `xaf2bb0d97d5d/xc7720e51b46a`, so `CombatFunctions:grip()` no longer stalls inside `UnRagdoll()` when a player presses Execute.

The public client package is `FunCombat_GitHub_Client_FIXED.zip`. The physical map and server source are intentionally not duplicated in that package.

Server source is intentionally not published in this repository. Obfuscation is source-hardening only; server authority is the security boundary.
