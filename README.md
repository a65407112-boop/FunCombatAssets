# Fun Combat GitHub Runtime

This folder is the client/runtime side of the split build. The matching place is `FunCombat_ServerLogicOnly.rbxl`.

## GitHub layout
Upload this folder **without renaming files**. GitHub Pages is not required; raw.githubusercontent.com is enough.

Set the raw folder URL and execute `loader.lua`:

```lua
getgenv().FUNCOMBAT_RUNTIME_URL = "https://raw.githubusercontent.com/YOURNAME/YOURREPO/main/FunCombat_GitHub_Runtime_Thin/"
loadstring(game:HttpGet(getgenv().FUNCOMBAT_RUNTIME_URL .. "loader.lua"))()
```

What the place sends on join: maps/world geometry, server-authoritative state/remotes, and ProximityPrompts. GUI, client scripts, morphs, VFX, sounds and keyframe animation trees are stored here and mounted locally by the runtime.

The server uses opaque names. The runtime translates them locally before the original client scripts start.

Object groups exported: {
  "starter_gui": {
    "file": "data/starter_gui.lua",
    "objects": 409,
    "scripts": 41
  },
  "player_scripts": {
    "file": "data/player_scripts.lua",
    "objects": 27,
    "scripts": 5
  },
  "character_scripts": {
    "file": "data/character_scripts.lua",
    "objects": 24,
    "scripts": 4
  },
  "replicated_core": {
    "file": "data/replicated_core.lua",
    "objects": 290,
    "scripts": 9
  },
  "weather": {
    "file": "data/weather.lua",
    "objects": 77,
    "scripts": 0
  },
  "anim_male": {
    "file": "data/anim_male.lua",
    "objects": 11831,
    "scripts": 0
  },
  "anim_female": {
    "file": "data/anim_female.lua",
    "objects": 9300,
    "scripts": 0
  },
  "anim_bat": {
    "file": "data/anim_bat.lua",
    "objects": 18325,
    "scripts": 0
  },
  "anim_other": {
    "file": "data/anim_other.lua",
    "objects": 5385,
    "scripts": 0
  },
  "anim_emotes": {
    "file": "data/anim_emotes.lua",
    "objects": 5093,
    "scripts": 0
  }
}


## Thin physical build
`FunCombat_ServerLogicOnly.rbxl` physically removes the external client/visual trees. `ServerStorage` is empty, `StarterGui` is empty, there are no stored LocalScripts, KeyframeSequences, Keyframes, Poses, ScreenGuis or BillboardGuis. Maps and ProximityPrompts are the intentional asset exceptions. Global lighting/post effects, UI, character presentation, sounds, VFX, morphs and animations are reconstructed only by the runtime.


## Opaque server build
The matching `FunCombat_ServerOpaque.rbxl` stores all physical server Script/ModuleScript source as encrypted hex payloads behind a minimal server-side loader. Server gameplay ModuleScripts were moved out of ReplicatedStorage into ServerScriptService. Gameplay attributes and MoveData keys use opaque protocol tokens. ProximityPrompt instance names/text remain opaque in the place and are translated locally by the runtime. The development `scripts_original` archive is intentionally absent.
