# Portable validation — three original prompt UI profiles

The user reported another flight after the original-menu repair. Their screenshot shows the visible avatar above a baseplate. It does not show the source root, proxy root/torso or camera measurements. The live cause has not been established or reproduced in an engine.

On October 14 the user reported that flight no longer occurs, but only one action prompt is visible on a ragdolled target. This is user feedback from a Roblox session, not a builder-run engine test. The previously published adapter creates two native prompts at identical UI positions. The user clarified that the original has three and attached the actual binary place. Its ProximityPrompt properties were decoded without interpreting geometry.

## Changes and evidence

- Three owned native UI profiles are restored: Execute (Default), Carry and :) (Default). Keys are E/T/R; offsets are (100,100), (-100,0) and (-100,100). The attached source's hold duration 0.30000001192092896 (float32), range 6, ObjectText Victim, native Default style, OnePerButton and shared gamepad ButtonX are preserved. The unpublished AlwaysShow/X-Y prototype was not released. During carry, the actual Drop/Finishing Hold source profiles replace the respective choices; recovery/removal hides or destroys the three prompts.
- **Only the third prompt's UI is restored. Its original paired action is not implemented in portable; clicking it reports a concrete unavailable-action error. No paired scene assets or animations are added, and it never substitutes another action.** Execute continues to route the existing local combat finisher and Carry/Drop remain functional. Three displayed source prompts do not mean three fully restored mechanics.
- Prompt provenance is the attached `fun combat v1.2 fixed torso(1).rbxl`, SHA-256 5872806f4484b2ef5d568cd4f94a114bee0c304b05d2f065dcfe76f6626b676e. The exporter reproduces all six source template profiles byte-for-byte and verifies the input checksum is unchanged. It reads names/parents and prompt properties only. The stored source's gamepad exclusivity can restrict simultaneous controller prompts; no engine test proves live keyboard/touch layout here.
- The previous adapter silently ignored an error setting proxy Humanoid.EvaluateStateMachine to false. The guard now disables and reads back this setting before Workspace parenting. It watches anchored/collision flags on owned body, head, accessory and weapon parts and checks them before simulation. If the required setting or repair fails, it removes the unsafe copy and restores source visibility. Offline tests cover successful readback, denied writes, reenabled collisions and isolation from the real root. This addresses a concrete unverified path; it does not prove the reported flight is fixed.
- Dash uses the original CombatServer timings, speed, horizontal MaxForce and original assets. Q and the original mobile Dash button select the same action. Only the current local player's actual root receives its temporary BodyVelocity; there is no root CFrame/anchor assignment. Offline checks cover startup, cooldown, horizontal force, expiration, interaction cancellation, character replacement and unload. Original limb effects retain Trail attachment references and never parent their source BasePart into Workspace. The original sounds/effects are warmed before dash input becomes available.
- The separate manual diagnose_flight.lua provides a 10-second Record and Copy report panel. It records real root, proxy root/torso, velocities, owned collisions/anchors, connections, forces and camera subject. It does not alter character motion, execute combat or inspect original model geometry. The main loader does not run it.
- Original weapon/Gender/emote/title/hit-feedback/name/health/gender GUIs, six original weapons, native head/clothes/colors, R6 locomotion and visual ragdoll remain in the portable adapter.

## Completed offline checks

134 grouped behavior checks/assertions:
14 virtual combat; 6 local bus; 8 visibility ownership; 4 late appearance; 6 bounded fetch; 2 equip/carry race; 5 kinematic weapon; 13 original GUI/input; 5 gender/respawn/reexecution/readiness; 6 visual ragdoll/map contact; 3 ragdoll isolation; 7 locomotion mode; 1 emote transition; 9 passive guard; 9 horizontal dash; 5 flight snapshot; 7 original dash effect ownership/lifetime; 24 source prompt properties, three-choice availability, input routing, unavailable action, carry profile transitions and cleanup.

A fresh independent review found no Critical/Important issue and three Minor issues. Copy now refuses a stale report while recording, mobile Dash hides when the local proxy leaves, and departing weapon parts are pruned from the passive guard's scan/callbacks. The latter two have observed-failure regression checks.

A fresh review of the three-profile update found no Critical/Important runtime issue. It identified that an output hard link could overwrite the exporter input; the same-file guard now rejects it. An observed-failure regression uses only a temporary copy, verifies byte-identical normal export, and confirms the uploaded original's checksum remains unchanged.

The tests execute the real Lua modules through liblua5.4 with small Roblox API boundary mocks where required. They do not run Roblox, native imports or rendering. Parser checks cover portable Lua files in the compatible syntax subset; this is not the Luau compiler.

Original shared module bytes and required resource paths are checked against the immutable source manifest/tree. Generated loader/diagnostic embedding, portable file lengths/SHA-256/Adler-32 and repeated builds are checked. Portable source has no server remote invocation. Its single intentional real-motion exception is the local player's horizontal dash. Publication verification compares changed blob SHAs, preserved remote paths and fresh raw loader/manifest/config/diagnostic URLs.

## Unverified and absent

No Studio/Roblox engine, PC/mobile executor, live flight reproduction, video/render/audio test, native file-import test, dynamic facial-animation test, real asset-permission test, older-client test or model geometry inspection was performed. Disabling Humanoid simulation and rendering classic clothing together still needs a client test. Horizontal force does not establish how the host game's physics or server will handle dash.

This adapter cannot change another player's server health, position or game state, nor replicate its local effects. The original map, map voting, admin authority, awakened dash, paired interactions/morphs/audio and extra costumes are not part of portable. Native dynamic-head data is preserved but its appearance is not proven. Layered body clothing is skipped.

Visual ragdoll map contact approximates a torso sweep/ground clearance. Limbs use a visual falling pose. This is not a claim of a complete original-game clone.

## Roblox test checklist

1. Fetch the fresh loader; choose a gender and test all six original weapon buttons, grip and swing motion on PC/mobile.
2. Test Q and the original mobile Dash button while moving and standing still. Confirm cooldown, horizontal movement, obstacle stopping and original effects/audio.
3. Dash, then carry/equip/respawn/unload. Confirm no lingering force and one GUI/proxy set after reexecution.
4. If flight occurs, run the separate diagnostic, press Record 10s, reproduce it and copy the report. Compare source position/velocity against proxy root/torso and camera before assigning a cause.
5. Chat spawn, ragdoll the local dummy and verify the three source prompt positions on PC/touch. Test Execute and Carry. The :) action must report not implemented, without performing another action. During carry, verify Drop and Execute (Finishing Hold); after recovery, all downed choices must hide. Verify the real character remains controllable during carry. Gamepad retains the source's shared ButtonX behavior.
6. Check map contact near walls/slopes, emote transitions, late appearance and original visibility restoration after unload.
