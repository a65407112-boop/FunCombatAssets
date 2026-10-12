# Portable validation

The new portable package uses an in-process event bus and virtual combat records. It adds two local prompts, Glory and Carry, and does not add an Execute GUI button. The existing server place and original client modules are not modified.

## Completed offline verification

- 14 virtual-combat behavior cases: timing, duplicate hits, combo knockdown, carry/drop, recovery, Glory, participant removal and both prompt actions on a briefly ragdolled target.
- 6 event-bus behavior cases; the bus has no server sender.
- 8 appearance/visibility ownership assertions plus 4 late-appearance arrival assertions.
- 6 fetch/integrity/timeout/cancellation cases.
- 2 controller equip/carry race checks.
- 3 collision-arrival checks, including a new real character part arriving during an existing ragdoll.
- Lua 5.4 parser checks over the Lua-compatible subset used by the portable scripts; this is not Luau CLI or engine execution.
- Original dependency bytes checked against the immutable upstream manifest; selected original resource paths verified against the upstream repository tree.
- Portable modules/configuration lengths, SHA-256, Adler-32 and rebuild stability checked.
- New portable code inspected for server remote invocation and creation; none are used.

A fresh independent review found and led to fixes for rejected equip leaving loading stuck, late avatar appearance not being copied, and late character parts missing local ragdoll collision exclusions. The corresponding regression checks pass.

## Not verified in Roblox

No Roblox/Studio engine is available here. No PC or mobile executor run, geometry inspection, render/audio/video test, actual multi-avatar physics test, facial-animation test, asset-permission test or older-client test was performed. Original geometry was not inspected, as requested. Keeping native head data and FaceControls does not prove facial animation rendering.

The local hit values and recovery timings are portable simulation configuration, not claims that another game's server accepts damage. A displayed local Glory/ragdoll does not prove the real player is downed or dead. This adapter cannot replicate these effects to other clients without a server implementation.

## Roblox test checklist

1. Execute the loader twice; one HUD and one local proxy per live character should remain.
2. Use Local dummy, land the three-swing combo, verify Glory and Carry prompts.
3. Carry/drop while walking; real movement should remain available.
4. Let both sides respawn/leave during carry and Glory; no partner should remain hidden or locked.
5. Spawn a character while another proxy is ragdolled; verify ragdoll copies do not collide with real character parts.
6. Check late hats, head assets and classic clothes, switch all six weapons, then unload and verify original visibility returns.
7. Repeat on PC/mobile and record concrete native-import errors instead of assuming compatibility.
