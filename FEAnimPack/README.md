# FEAnimPack

One-repo R6 raw KeyframeSequence GUI with 50 poses/animations.

## Execute

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/FEAnimPack/loader.lua"))()
```

## Features

- 50 animations from the generated KeyframeSequence pack
- built-in GUI
- search by animation/category
- play by clicking an entry
- Stop button
- 0.25x to 3.00x speed
- draggable window
- respawn handling
- duplicate-GUI cleanup
- no external UI library
- no published AnimationId required

## Files

- `loader.lua` - GUI and R6 Motor6D player
- `animations.lua` - all 50 compact pose sequences

## Replication note

This player applies raw pose data to your own R6 character through `Motor6D.Transform`. It is not a server bypass. Whether another player sees those raw client-driven transforms depends on Roblox and the particular game's replication behavior. A published animation permitted for the experience is the normal way to get reliable Roblox animation replication.
