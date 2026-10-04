# FunCombat Executor-Side Implementation Plan

> Execution: implement inline under the user's explicit instruction to complete
> the conversion without stopping at a plan. Use verification-before-completion.

**Goal:** Build a source-derived authoritative server and finish the existing external client.
**Architecture:** Python/rbxmk exports the source DOM; focused Luau server modules
own gameplay; the existing JSON-backed client presents confirmed state.
**Tech Stack:** Python 3.11+, lxml, zstandard, LZ4, rbxmk 0.9.1, Roblox Luau.
**Spec:** ../specs/2026-10-04-executor-side-design.md

## Global constraints
- Never edit the source. No geometry or visual verification.
- Protocol 4; opaque network IDs and original six character prompts and all map wall prompts.
- Original asset IDs, six weapons, two maps; no generic substitutions.
- All original costumes and paired mechanics included; third-party admin dependencies archived and disclosed.
- Roblox engine and legacy client validation unavailable.

## Review focus
- Invalid/NaN payloads cannot cause damage, overwrite other players or spawn unlimited NPCs.
- A removed/respawned participant cannot leave another character anchored or carried.
- Loading, rerunning and stale snapshots cannot lose current state or duplicate presentation.
- Archive rebuild must not overwrite its source or include stale executable assets.
- Build identity and all semantic/encoded action/event mappings must agree.

### Task 1: Server policy and gameplay
Files: Builder/templates/server/{Policy,CombatServer,Ragdoll,World,Voting,Main}.lua.
Interfaces: Policy validates data/state; CombatServer.new(services) owns records;
World.new(combat, protocol) owns environment; Voting.new(combat, world) owns maps.
- [ ] Write/run failing Policy tests for invalid input, cooldown, prompt holds and carry ownership.
- [ ] Implement Policy and source-derived gameplay modules; run Policy tests and Luau compilation.

### Task 2: Builder and exports
Files: Builder/{build,validate}.py; Builder/tests/test_builder.py.
Interfaces: build(source, rbxmk, output) produces Game_Server.rbxlx and GitHub/;
validate(output) checks XML references, runtime packages and protocol alignment.
- [ ] Write/run failing source-preservation, export/reference and deterministic-build tests.
- [ ] Export catalog roots/animations, assemble source map and generated server, build archives.
- [ ] Verify source checksum, XML decoder round trip and repeat-build byte identities.

### Task 3: Client lifecycle and protocol
Files: loader.lua; client/{networking,main,combat,world}.lua; config/protocol.json.
Interfaces: ctx.protocol; ctx.network:send/on/dispatch/snapshot; boot buffer and activation.
- [ ] Write/run failing networking tests for bootstrap event loss, wrong build, stale snapshot.
- [ ] Add encoded dispatch, dependency traversal, bootstrap buffering and respawn resnapshot.
- [ ] Restore dummy/door chat requests and source system notices.
- [ ] Run client factory syntax/lifecycle checks and existing outfit tests.

### Task 4: Verification and delivery
Files: docs/installation.md, Validation_Report.md, Changes_For_Review.md.
- [ ] Run all meaningful offline checks; separately review server/client integration.
- [ ] Update GitHub as requested, verify raw URLs, use ordinary fast-forward git push without rewriting history.
- [ ] Assemble requested archives/files and provide explicit engine-test limitations.
