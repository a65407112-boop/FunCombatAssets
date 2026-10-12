# Portable Fun Combat

Standalone executor presentation using the original FunCombat weapons, grip data, combat animations and sounds. No FunCombat server place or server protocol is required.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/portable/loader.lua"))()
```

Everything in this adapter is local: other players become blocky copies on your screen; weapon damage, ragdoll, Glory, Carry and scores apply to those copies. Real players' server health, movement and game state are unaffected. Other clients do not see these effects.

## Controls

- Left mouse / Attack button: three-hit original swing combo.
- 1–6 or HUD arrows: Bat, Sword, :3, BoyKisser, Maxwell, Orange Cat.
- Third combo strike or zero virtual health downs the target.
- **Glory (E)** and **Carry (T)** are the two local ProximityPrompt options on a downed/ragdolled target. Hold for 0.3 seconds within 6 studs.
- Glory uses the original combat grip finisher, or finishing-hold clips if carrying. It is a local combat presentation; it does not load paired morphs or paired interaction clips.
- Carry changes to Drop (T) while holding a target. The HUD Carry/Drop button also works on touch.
- Local dummy creates up to three local practice targets.
- × unloads the adapter and restores original local visibility. Re-running the loader disposes the previous session first.

There is no separate Execute button. Ordinary hit ragdoll is brief; the third combo hit leaves a downed target for 18 seconds. Local Glory results reset after 3 seconds. Carry and Glory are released on respawn/removal, including the partner's removal.

## Appearance and capabilities

Bodies are local classic R6 block shapes; heads, original mesh/texture references, classic clothing and head accessories are retained. Late appearance additions trigger a refreshed proxy. Layered body clothing is skipped because it cannot be reliably fitted to an R6 body without a separate adaptation. Actual character roots/joints are not rebuilt.

Required: loadstring and HTTP access. The original Bat and Orange Cat use structured Instance packages. Sword, :3, BoyKisser and Maxwell additionally require writefile, getcustomasset/getsynasset and local RBXMX support in getobjects/game:GetObjects. Unsupported imports report the actual weapon error; they are not replaced by invented meshes.

Owner/name/branch settings appear once at the top of `loader.lua` (source: `loader.template.lua`). Shared resource files are pinned to commit `72d4e7ffd5cde727b8b6f0180186e8a891278bed`. The separate portable manifest verifies module/config lengths and checksums; SHA-256 is also checked when the executor exposes a compatible crypt.hash.

## Rebuild and offline checks

```sh
python3 portable/build.py
python3 portable/tests/run_checks.py
```

The builder needs no RBXL or original map; it embeds the tested fetch module into one loader and regenerates portable integrity metadata. The Python checker requires liblua5.4 and tests Lua-subset syntax plus state/ownership/race behavior. It does not simulate Roblox rendering or physics and is not the Luau compiler.

See [Validation_Report.md](Validation_Report.md). Roblox engine/executor verification has not been performed. Native file import support, actual asset permissions, dynamic facial animation, physical ragdoll and older-client compatibility still require a Roblox test.
