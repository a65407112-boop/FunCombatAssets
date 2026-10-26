# Client world implementation plan

> Execute inline using superpowers:executing-plans; keep the existing morph code
> and assets untouched as requested. The user supplied the desired behaviour and
> asked to proceed without time spent examining morphs.

**Goal:** Load visible maps from GitHub, give ordinary joins a solid waiting room,
and move initialized loader players into the shared world.

**Architecture:** Keep invisible original server collision and triggers. Export
script-free native map models; a separate client/server session pair coordinates
map revisions, entry, respawns, cleanup and local player visibility.

**Tech stack:** Python/lxml/rbxmk builder; Luau runtime and offline API doubles.

**Spec:** ../specs/2026-10-26-client-world-design.md

## Global constraints

- Do not inspect, modify or test morph behaviour or assets.
- Keep original collidable geometry and world triggers; all visible maps load
  from repository packages.
- Keep eligible saved instance names opaque and native R6 settings unchanged.
- Update GitHub only after relevant offline checks; do not publish to Roblox.

## Review focus

- A slow or failed model load leaves the player on a solid room floor.
- A map switch during loading rejects the old revision and reloads safely.
- Respawn and repeated loader execution do not duplicate worlds or strand players.
- Late players and late character descendants follow local visibility state.
- Unload/network loss restores visibility and returns participation to the room.

## Task 1: Native world export and waiting room

- [x] Add failing tests for invisible presentation preserving physical properties,
  script-free exports, and a closed room with an enabled spawn.
- [x] Implement Builder/client_world_upgrade.py and binary model support in the
  existing asset importer, preserving original native binary property types.
- [x] Run builder tests, decode exported native models and verify counts/types.

## Task 2: World sessions and local presentation

- [x] Add failing Luau checks for room placement before readiness, stale/build
  rejection, idempotent join, map change, respawn, leave and lease expiry.
- [x] Implement ClientWorldSession.lua and client/world.lua, with generic local
  character visibility and moving-part synchronization.
- [x] Add client checks for load-before-join, failed loading, map races, cleanup
  and late character descendants. Run both real runtime modules with API doubles.

## Task 3: Assemble and deliver

- [x] Integrate the new modules into the binary and manifest; reseal hashes.
- [x] Verify native types, opaque saved names, original collision transforms,
  untouched unrelated scripts/assets and all relevant compile/regression checks.
- [x] Obtain one final independent code review, fix material findings, update
  GitHub main with an expected-head lease and deliver the new RBXL.
