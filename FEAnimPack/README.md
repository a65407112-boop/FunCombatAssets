# FEAnimPack

One-repo R6 raw KeyframeSequence GUI with 50 poses/animations.

## Execute

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/FEAnimPack/run.lua"))()
```

## Features

- 50 animations from the generated KeyframeSequence pack
- built-in GUI
- search by animation/category
- click an animation to play it
- Stop button
- 0.25x to 3.00x speed control
- draggable window
- respawn handling
- duplicate-GUI cleanup
- temporarily stops/disables the normal R6 `Animate` controller while the GUI is active so it does not fight the selected pose
- restores `Animate` when the GUI closes
- no external UI library
- no published `AnimationId` required

## Files

- `run.lua` - executable entry point; manages the normal Animate controller and starts the GUI
- `loader.lua` - GUI and R6 Motor6D pose player
- `animations_runtime.lua` - expands the compact pose data into runtime CFrames
- `animations.lua` - all 50 compact raw animation sequences

## Replication note

This player applies raw pose data to your own R6 character through `Motor6D.Transform`. It is not a server bypass. Whether another player sees those raw client-driven transforms depends on Roblox and the particular game's replication behavior. A published animation permitted for the experience is the normal way to get reliable Roblox animation replication.
