# Protocol 5: single saved rig and external original presentation

The builder produces the binary/XML place and both archives from the original
SHA256 a14ab714b5b3233a8e05fc5567ce1b9a7dc700ced2ccb2e13771c025f64142b0.
Source bytes are preserved. No model geometry is inspected.

## Changes

- One saved StarterCharacter outside original map/environment. The two distinct
  original NPC rigs are reconstructed from typed server data at runtime.
- Active Crossroads is saved once; its pristine template is cloned before
  voting. Original enabled spawns and both map choices remain.
- Replicated presentation constructor folders are removed. All original 129
  packages and 47 animations remain external. Six native model packages import
  original RBXMX with source node identity/hierarchy and writable-property checks.
- Saved non-engine object/module names, prompt labels, stats, game attributes
  and presentation resource tokens are encoded. Public mappings reverse them.
  Literal leaderstats, engine body/joint/service names and Kohl configuration
  interoperability are preserved. Server sources pool literals and remove
  comments without a VM or enabling loadstring.
- Protocol 5, matching builds, decoded broadcasts/snapshots and encoded actions
  retain authoritative combat/state. Action decoding has work/depth limits.
  Local stat labels handle late players and repeated loaders.
- R6 normalization retains torso/limb colors and native dynamic head data.
  User-ID dummies share this path. Success notices for dummy remain silent;
  previous voting and observer locomotion fixes remain.

## Offline checks

All 21 release suites passed. The Luau compiler accepted 44 generated/client/diagnostic files and all 23 embedded binary sources. An independent binary decode confirmed the packed-source semantic roundtrip, one saved rig and six native package identity sets. Rebuilding from the unpacked full archive produced identical binary/XML place, loader, diagnostic and both ZIP files. This byte comparison was made before adding its verification receipt; the final archives were resealed and CRC/content checked after adding documentation and the receipt.

Avatar regressions reproduce the deleted BodyPartDescription color bug, then
verify per-limb palettes, genuinely black parts, native/classic heads and
respawn/deadline cleanup. Native import checks cover external mode with no
replicated constructors, capability errors, original property application and
late-result disposal. RigFactory checks cover original reference binding and
failed-joint cleanup. Codec checks cover resource keys, map-vote dictionary
keys, Instance identity and oversized input rejection. Labels checks cover
late stats/players, values, cleanup and reexecution. Literal packing covers
escaped/long strings, comments, leading decimal numbers and string-argument
syntax. Existing combat, interaction, input, voting and loader suites remain.

Static_Checks.json records actual model/instance/prompt/spawn counts, package
membership, XML references/shared strings, packing roundtrip, binary property
types and manifest checks. Release_Checks.json records the release suites,
compilation, independent binary roundtrip and reproduction checks.

## Explicit limits

Roblox Studio/engine, real multi-client play, rendering, native avatar API,
facial playback, hosted permissions, phone/PC executor local-model support and
old-client/Bloxstrap compatibility are not tested here. The executor must
actually import local original RBXMX; missing support fails with a bounded
explicit error. Roblox may reject hosted mesh/texture/audio/animation/admin
resources independently of GitHub availability.

No replacement resources, head textures, uniform body colors or arbitrary
scale factors are introduced. Native rig construction may report unsupported
noncritical engine properties; core parts, joints, palette and gameplay
Humanoid fields are mandatory. Map/environment physics and native avatar data
remain in the place. Hosted Kohl can create runtime UI/network; its complete
upstream code is not bundled. Runtime player/NPC Models are expected.

This source-derived packaging/adapter implementation has offline checks; it is
not a fully playtested visual-copy claim. Obfuscation is public and reversible;
it does not establish secrecy or moderation compliance. Previous verification
history is in docs/history/verification_pre_v5.md.
