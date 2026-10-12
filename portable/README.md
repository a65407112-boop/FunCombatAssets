# Portable Fun Combat

The portable adapter restores the original weapon selector, Gender selector, title, emote panel, hit feedback and name/health/gender billboards from the original exported GUI packages.

~~~lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/portable/loader.lua?t=" .. tostring(os.time())))()
~~~

Choose **Female**, **Male** or **Fembxy** in the original Gender panel, then open the original weapon menu. Its six original buttons select Bat, Sword, :3, BoyKisser, Maxwell or Orange Cat. Gender and the last weapon choice survive a respawn and reexecution.

## Controls

- Click, or an unconsumed world tap on touch: original three-swing combo.
- Original weapon icon: open/close the weapon menu.
- Original emote panel: five original emote Pose sequences; moving cancels the emote.
- Hitbox toggle: show local target torso bounds.
- A ragdolled/downed copy presents **Glory (E)** and **Carry (T)**. Hold 0.3 seconds within 6 studs.
- While carrying: Drop prompt, T or Backspace.
- Chat **spawn**, **:dummy** or **:spawndummy**: local practice dummy (maximum three).
- End: unload. Touch users can unload by calling the current __FunCombatPortable_v1.destroy() through getgenv() or _G.

There is no separate Execute button or custom combat HUD. Errors use the original subtitle label after initialization; initialization failures have a small closable text box.

## Local presentation

Everything is local. Other players become blocky R6 copies on your screen. Damage, ragdoll, Glory, Carry and scores apply to those copies; real health, roots, movement and game state are untouched, and other clients do not see the effects. Glory uses the original combat grip/finishing-hold clips, without paired morphs, paired clips or paired audio.

Original heads, mesh/texture references, classic clothing, colors and head accessories are copied from the actual character. Late appearance arrivals refresh the copy. Layered body clothing is skipped. The native head data and FaceControls are retained; facial rendering still requires an engine test.

Bodies, accessories and weapons stay anchored and noncolliding throughout. The weapon renderer applies the original Tool.Grip, RightGripAttachment and current animated RightGrip in the same pass as the body. Visual ragdoll uses gravity plus map ray probes; it does not create collidable assemblies, BallSocketConstraints or forces. Its map contact is an approximate visual solver, not the original engine ragdoll physics. Walking uses the original R6 animation IDs and lean constants.

## Dependencies and limits

Required: loadstring and HTTP access. Bat and Orange Cat use structured Instance packages. Sword, :3, BoyKisser and Maxwell additionally require writefile, getcustomasset/getsynasset and local RBXMX support in getobjects/game:GetObjects. A missing capability reports the actual weapon error; no replacement meshes are generated.

Repository settings are at the top of loader.lua, generated from loader.template.lua. Original resources remain pinned to commit 72d4e7ffd5cde727b8b6f0180186e8a891278bed. Portable manifest version 2 verifies file lengths/checksums and optional SHA-256 when crypt.hash is compatible.

This is a portable presentation adapter, not a full copy of the original place. The original map, server map voting, admin authority, real damage, dash displacement, paired interactions, paired morphs and extra costumes are not installed in another game. The original mobile Dash/GetUp controls are hidden here because those server mechanics are not supplied by this adapter. Others' gender labels appear only when their source character exposes an original gender attribute.

## Rebuild and verification

~~~sh
python3 portable/build.py
python3 portable/tests/run_checks.py
~~~

The builder needs no RBXL. The checker needs liblua5.4 and runs Lua-subset syntax and offline boundary/state tests. See [Validation_Report.md](Validation_Report.md).

No Roblox/Studio engine is available here. PC/mobile executor rendering, native file imports, real asset permissions, dynamic facial animation, animation layering, actual ragdoll appearance and older-client compatibility have not been tested. Original model geometry was not inspected.
