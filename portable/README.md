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
- **Q**, or the original mobile **Dash** button: horizontal dash after selecting a gender and equipping a weapon.
- Hitbox toggle: show local target torso bounds.
- A nearby ragdolled/downed copy presents three native source prompts: **Execute (Default) (E)**, **Carry (T)** and **:) (Default) (R)**. Hold 0.3 seconds within 6 studs. The attached source's UI offsets, OnePerButton exclusivity and gamepad ButtonX values are retained. Keyboard/touch prompts have three distinct positions; gamepad retains the source's shared button rather than inventing new controls.
- **:) (Default)** starts a local paired dance using the original ordinary **Boston Breakdance** emote on both copies. The third prompt becomes the source **Stop (E)** profile. It ends after one clip or when either source participant moves, disappears or respawns; unload also releases both participants.
- While carrying: Drop prompt, T or Backspace.
- Chat **spawn**, **:dummy** or **:spawndummy**: local practice dummy (maximum three).
- End: unload. Touch users can unload by calling the current __FunCombatPortable_v1.destroy() through getgenv() or _G.

There is no separate Execute button or custom combat HUD. Errors use the original subtitle label after initialization; initialization failures have a small closable text box.

**The :) action is a dance adaptation, not an exact port of the original DefaultFun handler.** Both copies play the same existing Boston Breakdance clip with a shared start time and stand three studs apart. Clothing, heads and body colors remain intact. No original paired scene clips, morphs, scene audio or emitters are installed by this action. It does not execute the target, change health or award kills; the target's prior downed/ragdoll flags and remaining recovery time return when the dance ends. Failed loading reports its specific error instead of reserving the participants indefinitely. Execute routes the existing local combat finisher, and Carry/Drop remain functional. During carry, the source Drop and Execute (Finishing Hold) profiles replace the two corresponding downed profiles.

The prompt profiles come from `fun combat v1.2 fixed torso(1).rbxl`, SHA-256 `5872806f4484b2ef5d568cd4f94a114bee0c304b05d2f065dcfe76f6626b676e`, and are stored in prompt_templates.json. The source names and offsets are: Execute `(100,100)`, Carry `(-100,0)`, :) `(-100,100)`. ObjectText remains the original `Victim`.

## Local presentation

Other players become blocky R6 copies on your screen. Damage, ragdoll, Execute, Carry, the dance and scores apply to those copies; other clients do not see these effects. Those actions do not change real health, roots or game state. Execute uses the original combat grip/finishing-hold clips, without paired morphs, paired clips or paired audio. Moving your actual character ends a dance instead of anchoring it.

Dash deliberately moves your own actual character horizontally. It uses the original 0.15-second startup, 0.3-second duration, 60-stud/second velocity (nominal distance 18 studs) and 1.35-second cooldown. MaxForce is (30000, 0, 30000); the script never teleports or anchors your actual root. It uses the original weapon DashSound/normal audio, limb trails, ground smoke and white flash. A short forward map ray stops it at obstacles; interactions, character replacement and unload remove its force. The host game's server can override local movement. Roblox/PC/mobile execution is unverified.

Original heads, mesh/texture references, classic clothing, colors and head accessories are copied from the actual character. Late appearance arrivals refresh the copy. Layered body clothing is skipped. The native head data and FaceControls are retained; facial rendering still requires an engine test.

Bodies, accessories and weapons are anchored and noncolliding. A guard checks those flags and disables/reads back the proxy Humanoid's EvaluateStateMachine before it enters Workspace. If the client refuses these settings, the unsafe copy is removed and the original character's visibility restored, with a concrete error. The weapon renderer applies the original Tool.Grip, RightGripAttachment and current animated RightGrip in the same pass as the body. Visual ragdoll uses gravity plus map ray probes; it does not create collidable assemblies, BallSocketConstraints or forces. Its map contact is an approximate visual solver, not the original engine ragdoll physics. Walking uses the original R6 animation IDs and lean constants.

## Separate flight diagnostic

The screenshot of a character above the map does not establish whether the real root moved, the visual body drifted or the camera changed. The precise cause remains unconfirmed. The simulation-setting error was previously hidden; it is now checked. This is not an engine-confirmed fix of the reported flight.

Run this manual diagnostic only when needed; the normal loader never runs it:

~~~lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/a65407112-boop/FunCombatAssets/main/portable/diagnose_flight.lua?t=" .. tostring(os.time())))()
~~~

Press **Record 10s**, reproduce the flight, then **Copy report**. It reads source/proxy root and torso positions, velocities, collision/anchor flags, connected proxy parts, existing forces and the camera subject. It does not move or stop either character, inspect meshes or issue combat commands. Close removes its panel. The report distinguishes observations from a diagnosis.

## Dependencies and limits

Required: loadstring and HTTP access. Bat and Orange Cat use structured Instance packages. Sword, :3, BoyKisser and Maxwell additionally require writefile, getcustomasset/getsynasset and local RBXMX support in getobjects/game:GetObjects. A missing capability reports the actual weapon error; no replacement meshes are generated.

Repository settings are at the top of loader.lua, generated from loader.template.lua. Original resources remain pinned to commit 72d4e7ffd5cde727b8b6f0180186e8a891278bed. Portable manifest version 2 verifies file lengths/checksums and optional SHA-256 when crypt.hash is compatible.

This is a portable presentation adapter, not a full copy of the original place. The original map, server map voting, admin authority, real damage, awakened dash, original DefaultFun interactions/morphs/audio and extra costumes are not installed in another game. The third action described above is an ordinary-emote dance adaptation. The original mobile GetUp control remains hidden; Dash is connected to the local dash adapter. Others' gender labels appear only when their source character exposes an original gender attribute.

## Rebuild and verification

~~~sh
python3 portable/build.py
python3 portable/tests/run_checks.py
~~~

The builder needs no RBXL. The checker needs liblua5.4 and runs Lua-subset syntax and offline boundary/state tests. See [Validation_Report.md](Validation_Report.md).

To reproduce the prompt profile export from the attached source, run:

~~~sh
python3 portable/export_prompts.py "fun combat v1.2 fixed torso(1).rbxl"
python3 portable/tests/verify_prompt_export.py "fun combat v1.2 fixed torso(1).rbxl"
python3 portable/build.py
~~~

The exporter reads only instance names/parents and ProximityPrompt presentation properties, not script contents, meshes or animation poses. It refuses to overwrite its input. Compressed chunks require `lz4` or liblz4, and `zstandard` for Zstandard chunks. Unsupported source keys/property types fail explicitly.

No Roblox/Studio engine is available here. PC/mobile executor rendering, native file imports, real asset permissions, dynamic facial animation, animation layering, actual ragdoll appearance and older-client compatibility have not been tested. Original model geometry was not inspected.
