# Portable Fun Combat design

Standalone executor presentation in the existing FunCombatAssets repository, with original weapon models, grip data, combat Pose sequences, sounds and original GUI packages. It operates on local copies without a FunCombat server protocol. The requested appearance is a character and interface transplanted from original FunCombat, including the original weapon menu, Gender selection and name tags.

## Runtime

- One generated portable loader holds repository settings and pins original resources to commit 72d4e7ffd5cde727b8b6f0180186e8a891278bed.
- Original client cleanup/assets/animations/audio modules are unchanged. A local event bus and virtual records supply their state dependencies.
- Original GUI trees are restored from source packages, with a portable action/state adapter.
- Local R6 models copy source head/colors/classic clothes/head accessories. Real character roots, health and joints remain untouched.
- Every copy part and weapon stays anchored/noncolliding. Body and original animated RightGrip frames are drawn explicitly each frame.
- Visual ragdoll uses bounded gravity integration and map sweeps; it does not install collidable assemblies or physics forces. Walls are swept before floor contact.
- Original R6 animation IDs/lean constants provide gait; original combat curves override the authored limbs.
- Gender choice and selected weapon persist across respawn/reexecution. A controller synchronizes already-ready actors at construction.
- Two local Glory/Carry prompts; Carry becomes Drop. Glory is the original combat finisher; no separate Execute GUI button or paired morph/clip/audio.
- Hits, health, scores and all results are virtual. Third combo/zero virtual health downs a copy. Removal/unload releases both participants.
- Missing native imports produce actual errors. No invented weapon geometry.

## Validation boundary

Offline liblua5.4 checks cover state, fetching, ownership, original GUI bindings, numeric motion, grip rendering and selection/readiness races. They are not a Roblox engine or Luau CLI.

Original model geometry is not inspected. Rendering, animation playback/layering, permissions, physical appearance, native imports and older clients remain unverified. Extra costumes, paired interactions, admin, map voting, server damage and real dash displacement are outside portable; see portable/README.md.
