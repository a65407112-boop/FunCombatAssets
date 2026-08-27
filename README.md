# FunCombatAssets — server-only map/prompts rebuild

The old Lua-serialized runtime (`core.lua`, `data/*.lua`, `loader_*`, UI hotfixes) is gone.

## Final architecture

The published Roblox place contains only the physical world/map, ProximityPrompts, replicated networking endpoints, and hidden server gameplay code.

- `StarterGui` is empty.
- `StarterPlayer` contains no client scripts.
- No LocalScripts are shipped in the server place.
- Full animations, morphs, VFX, sounds, weapon visuals and GUI are client assets and are not stored in ReplicatedStorage.
- Gameplay modules are hidden in ServerStorage under opaque names.
- ReplicatedStorage exposes only opaque Remotes/RemoteEvents, prompt templates, and the Gender SetInfo endpoint.
- Weapon selection is server state. The client does not give itself a Tool.
- Client attacks send only an allowed move ID; the server validates combo/cooldown and computes hitboxes/victims with `workspace:GetPartBoundsInBox`.
- Damage, ragdoll/downed, carry/execute, Gender, emote permission, killstreak/awaken and player interaction remain server-authoritative.
- Presentation is broadcast as state/events so separate client RBXM assets can render it.

Deployable server build: `FunCombat_ServerOnly_MapPrompts.rbxl`.

Server source is intentionally not published in this repository. Obfuscation is only source-hardening; server authority is the actual security boundary.
