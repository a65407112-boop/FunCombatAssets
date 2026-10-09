# Protocol 5 release changes

This release replaces the protocol-4 stored-rig/native-constructor layout. Publish the whole new place and join a fresh server before loading the matching client.

- One saved original StarterCharacter outside original map/environment; both distinct original NPC rigs reconstruct at runtime.
- Original Crossroads is saved once and cloned into a pristine runtime voting template; the other source map remains.
- All 129 presentation packages and 47 animations remain external. Six original native packages use local RBXMX import; no replicated constructor fallback remains.
- Opaque saved names, prompt labels, stats, game attributes, presentation keys and packed server sources use public consistent bindings. Required engine/Kohl names remain.
- Native dynamic head handling remains. R6 body normalization keeps individual torso/limb colors instead of destroying synchronized BodyPartDescription colors.
- Protocol 5 codecs preserve authoritative state, late joins, respawns and local-readable labels. Manual diagnostics show readable fields; dummy diagnostics use forward server attribute aliases.
- Existing carry, observer locomotion, voting and silent dummy-success behavior remain.
- Builder archives are written atomically, file membership is deterministic, and the original source is retained unchanged.

21 offline suites, 44 generated/client script compiles, 23 embedded source compiles and full archive reproduction passed. No Roblox engine, executor rendering, hosted permissions, PC/phone or legacy-client test ran. Geometry was not inspected. Obfuscation is reversible and is not a moderation or secrecy guarantee.
