# Single saved rig implementation plan

> **For agentic workers:** Use native execution in this session. Track the tasks below and run their verification before publishing.

**Goal:** Produce the requested original game with one saved rig outside map/environment and external original presentation.

**Architecture:** Extend the source-specific builder with a compact finalization pass. Keep readable templates and original typed exports reviewable in GitHub; save packed sources and opaque bindings in the place. Reuse the authoritative combat, state, avatar and interaction runtime.

**Tech Stack:** Python/lxml, rbxmk 0.9.1, Roblox Luau, typed JSON and original RBXMX model exports.

**Spec:** docs/superpowers/specs/2026-10-09-single-rig-design.md

## Global constraints

- Original source SHA256 a14ab714b5b3233a8e05fc5567ce1b9a7dc700ced2ccb2e13771c025f64142b0 is unchanged.
- Exactly one saved character Model outside original map/environment; runtime NPC Models are allowed.
- Preserve all 129 packages and 47 original animations; inspect no geometry.
- Protocol 5 and matching build IDs; no replicated native presentation fallback.
- Keep engine-required character names and literal leaderstats; preserve Kohl configuration interoperability.
- No Roblox engine or executor compatibility claim from static checks.

## Review focus

- Escaped strings, long strings, comments and adjacent numeric tokens must retain their Luau meaning.
- Initial map backup must exist before voting, with original enabled spawns.
- Native import completion after timeout/cleanup must destroy late Instances.
- Wire decoding must preserve Instance references and dictionary map-vote keys.
- Local stat renaming must handle late players, re-execution and respawn without server lookup changes.

## Task 1: Source-derived runtime rigs

- [ ] Test Factory-created typed original rigs for correct parent/reference binding and partial-failure cleanup.
- [ ] Add Builder/templates/server/RigFactory.lua and compact rig-data extraction for original DUMMY/DummyRig.
- [ ] Replace generated dummy cloning and create the initial dummy before CombatServer:start.
- [ ] Remove saved NPC rigs and redundant Crossroads template; clone its pristine backup before voting.

## Task 2: Strict external original model import

- [ ] Test successful native import, unsupported capabilities, count mismatch and late completion cleanup.
- [ ] Route every package containing MeshPart/SurfaceAppearance/UnionOperation through the original RBXMX import.
- [ ] Remove both replicated native-constructor folders; add actual import warmup/protocol checks before UI initialization.

## Task 3: Opaque saved and wire bindings

- [ ] Test literal packing roundtrip and compile packed modules with escaped/long strings.
- [ ] Implement Builder/compact.py and Builder/luau_pack.py with deterministic object/stat bindings and reversible literal pools.
- [ ] Add WireCodec and client labels; test resource and map-name roundtrips with table keys and Instances.
- [ ] Rewrite generated instance/attribute/module lookups consistently; keep native engine and Kohl exceptions explicit.

## Task 4: Build, report and deployment

- [ ] Run all existing offline suites and new compact/import/codec/rig scenarios.
- [ ] Build final binary/XML place and archives from the untouched source.
- [ ] Decode the binary, check the single-rig/native-resource rules, compile embedded sources and verify source/protocol/package integrity.
- [ ] Update installation and verification documentation, reseal manifests and reproducible archives.
- [ ] Publish the exact checked tree with expected_sha protection; verify raw manifest/protocol/loader and binary Git hash.
- [ ] Save all final download artifacts and hand them over, stating the untested engine/executor limitations.
