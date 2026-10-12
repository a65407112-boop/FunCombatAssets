# Portable Fun Combat design

The requested result is a standalone executor loader in the existing FunCombatAssets repository. It uses the existing weapon models, grip data, combat Pose clips and sounds, and works without the FunCombat server protocol. All combat results and changed avatar presentation are local to the executor's client.

The user requires two local prompts named Glory and Carry and forbids a separate Execute button. Glory is implemented as the original combat grip/finishing-hold sequence. No paired morph, paired animation variant or paired sound effect is added.

## Runtime

- A single `portable/loader.lua` contains the repository owner/name/branch settings.
- `portable/manifest.json` describes portable modules/configuration and pins shared original resources to upstream commit `72d4e7ffd5cde727b8b6f0180186e8a891278bed`.
- Reuse `client/cleanup.lua`, `assets.lua`, `animations.lua`, `weapons.lua`, `audio.lua` unchanged. Replace their networking/state dependencies with an in-process event bus and virtual combat records. Never create or invoke a RemoteEvent/RemoteFunction.
- Each source player/NPC is represented by a local classic R6 model. After a proxy is ready, hide the original locally. Retain source colors, head, head accessories and classic clothing. Skip layered body accessories. Real character joints, root transforms, health and movement remain untouched.
- Upright and carried proxies are anchored and positioned explicitly from their Motor6D frames. Carry uses a visual offset from the real local root, never a weld to the real character. Ragdoll releases only proxy motors, installs BallSocketConstraints and prevents contact with all known real character parts using local NoCollisionConstraints.
- Default weapon is the original Bat. All six original weapons are available; four require native `.rbxmx` support through writefile/getcustomasset/GetObjects. Do not invent replacement mesh geometry.
- Hits use local distance, facing, line-of-sight, startup/cooldown and a once-per-swing target set. Damage is virtual; a third combo strike or zero virtual health downs the target.
- A downed/ragdolled target presents Glory and Carry. Glory plays original combat finisher clips and only changes virtual health. Carry changes to Drop while held. There is no separate Execute GUI button. Virtual results recover after the configured local recovery time.
- Respawn, leaving, removal, unload and repeat execution release both sides of every local carry, dispose owned objects, restore original local visibility and cancel stale loading callbacks.
- Compact HUD and native local prompts support PC and touch. Provide a local dummy for testing without another player. Errors never use a fullscreen backdrop.

## Files

`portable/core.lua`: virtual state and lifecycle, no Roblox API dependency.
`portable/bus.lua`: local event dispatch and clock, no server transport.
`portable/avatars.lua`: blocky proxies, source appearance/visibility, posing, local ragdoll and prompt lifecycle.
`portable/controller.lua`: input-independent weapon/swing/Carry orchestration, local hit queries, original sound/effect scheduling.
`portable/ui.lua`: compact controls, target display and error status.
`portable/loader.lua`: bounded fetching, checksums, module loading, singleton and startup cleanup.
`portable/config.json`, `manifest.json`, `README.md`, `Validation_Report.md`: reproducible configuration, integrity and usage.
`portable/tests/run_checks.py`, `core.spec.lua`, `bus.spec.lua`, `runtime.spec.lua`: offline syntax, behavior and ownership checks.

## Verification and limits

Exercise virtual hit timing/duplicates, carry/drop, cancellation on actor/target removal, recovery, disconnect during event dispatch, source visibility restoration, RGB selection and stale respawn callbacks. Verify shared asset file checksums and every selected resource path. Check the remote diff only adds portable/documentation files and updates the root manifest's file inventory.

The workspace contains liblua5.4, not a Roblox engine or Luau CLI. Keep new scripts in the Lua 5.1-compatible subset of Luau; distinguish Lua parser/mock checks from actual Roblox tests. Physics, rendering, GetObjects support, real asset permissions and old-client behavior need Roblox executor testing. Do not inspect original model geometry.
