# Portable validation — original presentation repair

User feedback on the first portable release reported broken swords, a player being flung and an unwanted custom HUD. These reports are not treated as successful Roblox verification of this repair.

## Changes and evidence

- The previous weapon adapter made cosmetic parts unanchored and relied on engine joints while the blocky body was drawn manually. The new portable renderer anchors all weapon parts, retains the original asset/grip/relative frames and explicitly applies the animated RightGrip after body rendering.
- The previous ragdoll enabled physics contacts on its local copies. The new path never makes a proxy collidable or unanchored; it uses a visual gravity/map-probe solver. This removes that potential force-transfer path. The precise live cause of the reported fling was not reproduced in an engine.
- Original exported weapon/Gender/emote/title/hit-feedback/name/health/gender GUI packages replace the custom HUD. Runtime bindings, cached synchronous equip, proper source display names and local selection persistence have offline coverage.
- Original R6 locomotion IDs and lean constants replace the improvised sine gait. Mode selection has offline coverage; actual animation playback is unverified.
- A fresh independent code review identified a readiness event occurring before controller creation and a floor probe bypassing wall sweeps. Both have regression checks and fixes. An emote-to-carry regression also ensures cancelling an emote does not stop the new carry animation.

## Completed offline checks

76 grouped behavior checks/assertions:
14 virtual combat; 6 local bus; 8 visibility ownership; 4 late appearance; 6 bounded fetch; 2 equip/carry race; 5 kinematic weapon; 9 original GUI; 5 gender/respawn/reexecution/readiness; 6 visual ragdoll/map contact; 3 ragdoll isolation; 7 locomotion mode; 1 emote transition.

The tests execute the real Lua modules through liblua5.4 with small Roblox API boundary mocks where required. They do not run Roblox, native imports or rendering. Parser checks cover portable Lua files in the compatible syntax subset; this is not the Luau compiler.

Original module checksums and original resource paths are checked against the immutable source manifest/tree. Generated loader embedding, portable file lengths/SHA-256/Adler-32 and repeated builds are checked. New portable source has no server remote invocation and no body-part force/velocity assignment. Publication verification compares blob SHAs and refetches raw loader/manifest/config URLs.

## Unverified and absent

No Studio/Roblox engine, PC/mobile executor, video/render/audio test, native file-import test, dynamic facial-animation test, real asset-permission test, older-client test or model geometry inspection was performed.

This adapter cannot change another player's server health, position or game state, nor replicate its local effects. The original map, map voting, admin authority, real dash displacement, paired interactions/morphs/audio and extra costumes are not part of portable. Native dynamic-head data is preserved but its appearance is not proven. Layered body clothing is skipped.

Visual ragdoll map contact approximates a torso sweep/ground clearance; it is deliberately different from collidable engine ragdoll physics. Limbs are a visual falling pose. This is not a claim of a complete original-game clone.

## Roblox test checklist

1. Fetch the fresh loader; the original Gender panel should appear. Choose each supported option and inspect original name/gender tags.
2. Use the original weapon icon and all six buttons. Check grip orientation and swing motion on PC/mobile; record any concrete native-import error.
3. Chat spawn, hit the local dummy and verify Glory/Carry/Drop prompts.
4. Verify the real character remains controllable during carry and that local ragdoll cannot push it.
5. Hit a copy near walls/slopes and inspect visual floor contact.
6. Use an emote, then carry/equip/move. Repeat after respawn and reexecute during initialization.
7. Unload/reexecute; original local visibility should return and one set of GUIs/proxies should remain.
