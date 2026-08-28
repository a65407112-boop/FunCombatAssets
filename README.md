# FunCombat Runtime

External presentation/input runtime generated only from `fun combat v1.2 fixed torso.rbxl`.

Versions: `GAME_BUILD=fc-20260828-03`, `PROTOCOL_VERSION=2`,
`RUNTIME_VERSION=1.1.0`, `ASSET_VERSION=2`.

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
│   └── admin_templates.lua
├── characters/pack.lua
├── weapons/pack.lua
├── morphs/pack.lua
├── vfx/
│   ├── pack.lua
│   ├── weather.lua
│   └── lighting.lua
├── sounds/pack.lua
├── animations/
│   ├── index.lua
│   ├── manifest.lua
│   └── data/*.lua
└── scripts/original/
    ├── manifest.json
    └── *.lua.txt
```

`animations/data/` contains 55 original KeyframeSequence/Pose exports
(47 runtime sequences + 8 development-save sequences).
Playback uses the exported transforms, not AnimationId.

## Publish and execute

The generated loader is already pointed at:

```text
https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/
```

Upload the contents of this folder to the root of that repository, then execute:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/loader.lua?ui=20260828-02", true))()
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

The runtime directly replaces the removed GUI LocalScripts: WEAPONS opens/closes the picker,
weapon choices equip the selected local Tool, the emote drawer and buttons work, gender choices
are submitted through opaque actions, mobile dash/recovery/phase and shift-lock controls are
wired, hitbox visualization is presentation-only, and the map-vote GUI reflects server votes.

## Boundary and trust model

The runtime sends numeric action identifiers. The server chooses timing, target hitbox,
health changes, lock duration, launch, physics state, interaction validity and cooldowns.
Client assets are presentation only. The archived original scripts are never executed.

The only deliberately readable runtime instance name is Roblox's structural Tool child
`Handle`; gameplay/protocol/prompt/runtime instance names remain opaque.

## Compatibility notes

This build is structurally verified but was not play-tested in Roblox Studio. Hidden
UnionOperation payload properties may require an execution environment that exposes
`sethiddenproperty`; other MeshPart/texture/sound properties use ordinary Roblox APIs.
