# FunCombat Runtime

External presentation/input runtime generated only from `fun combat v1.2 fixed torso.rbxl`.

Versions: `GAME_BUILD=fc-20260829-05`, `PROTOCOL_VERSION=4`,
`RUNTIME_VERSION=1.3.0`, `ASSET_VERSION=4`.

## GitHub layout

```text
FunCombat_Runtime/
├── loader.lua
├── loader_local.lua
├── core.lua
├── protocol.lua
├── names.lua
├── README.md
├── assets/
│   ├── manifest.lua
│   └── index.lua
├── gui/
│   ├── pack.lua
│   ├── admin_templates.lua
│   └── feedback.lua
├── characters/pack.lua
├── weapons/pack.lua
├── morphs/pack.lua
├── vfx/
│   ├── pack.lua
│   └── weather.lua
├── sounds/pack.lua
├── animations/
│   ├── index.lua
│   ├── manifest.lua
│   └── data/*.lua
└── scripts/README.md
```

`animations/data/` contains 55 original KeyframeSequence/Pose exports
(45 presentation sequences wired by the runtime + 10 reference/development sequences).
Playback uses the exported transforms, not AnimationId.

## Publish and execute

The generated loader is already pointed at:

```text
https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/
```

Upload the contents of this folder to the root of that repository, then execute:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/loader.lua?ui=20260829-04", true))()
```

The query tag forces a fresh runtime after an update. Rejoin the server before running a newer
runtime build so callbacks from an already-running older loader cannot remain connected.

`FUNCOMBAT_RUNTIME_BASE` remains available as an optional override for forks or local mirrors.

For a local checkout with `readfile`, set `FUNCOMBAT_RUNTIME_LOCAL_ROOT` and execute
`loader_local.lua`.

The loader performs the four-field handshake before loading any asset pack. A mismatch
stops with a clear error. Runtime-created instance names stay opaque; only player-facing
text (prompt labels and UI text) is translated locally.

Runtime controls preserve the source behavior: tool activation cycles the three-hit combo,
`Q` dashes, `G/H/J/K/L` play the five emotes, and `G` becomes recovery input while downed.
During an interaction, `R` requests the next phase; the server independently validates the
authoritative meter threshold before accepting it. Exported morphs are applied and cleared
locally from opaque server presentation events.

The runtime directly replaces the removed GUI LocalScripts. Windows are mutually exclusive and
survive respawn: WEAPONS toggles the picker, weapon selection equips the local presentation Tool,
the emote drawer closes after selection, gender closes after a valid choice, and the custom admin
panel opens/closes and switches tabs. Mobile dash/recovery/phase, shift-lock, hitbox preview and
map voting are wired. One guarded music controller owns the playlist, stops stale runtime tracks,
and never imports a Sound with `Playing=true`.

Every compatible client reconstructs the source R6 presentation shell over the invisible server
physics proxy. Weapon selection, trails, embedded keyframe animation, impact VFX/sounds, morphs,
carry/execute presentation, awaken effects and current state are broadcast by the authoritative
server and resynchronized after runtime startup. Therefore two players running the same build see
each other's presentation and interact through the same server state.

The custom admin panel is returned only to Studio users, the user/group owner, and the source
allowlist. Kick/kill/remove commands use prefix resolution and rate limits and are authorized and
executed by the server; the original unauthenticated admin remote is not retained.

## Boundary and trust model

The runtime sends numeric action identifiers. The server chooses timing, target hitbox,
health changes, lock duration, launch, physics state, interaction validity and cooldowns.
Client assets are presentation only. Original place script sources are not shipped in this
public runtime; `core.lua` is the generated presentation/input bridge.

The only deliberately readable runtime instance name is Roblox's structural Tool child
`Handle`; gameplay/protocol/prompt/runtime instance names remain opaque.

## Compatibility notes

This build is structurally verified but was not play-tested in Roblox Studio. Hidden
UnionOperation payload properties may require an execution environment that exposes
`sethiddenproperty`; other MeshPart/texture/sound properties use ordinary Roblox APIs.
