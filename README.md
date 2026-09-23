# Fun Combat — external combat client (assembled combat build)

This repository contains real source-derived asset packages and an implemented external client. **It is not a verified playable release.** The matching `FunCombat_Server.rbxlx` is included in the full project package; its structure is checked offline. This loader does not work against the unmodified original place.

The sole source is `fun combat v1.2 fixed torso.rbxl`, SHA-256 `5872806f4484b2ef5d568cd4f94a114bee0c304b05d2f065dcfe76f6626b676e`.

Included: six original weapon models and attachment data, 23 stored combat/carry/execution/awakening/custom-emote sequences, original GUI/effect/audio/weather data, server state rendering, R6 locomotion, input, native prompts, voting, respawn binding and idempotent cleanup. The explicit sexual-interaction branch is excluded. Prompt names and visible labels are deterministic opaque codes. The external client restores readable labels locally; source map and asset names are preserved.

Upload **this folder's contents**, with `loader.lua` and `manifest.json` at repository root. The one repository configuration is `CONFIG` at the top of `loader.lua`. It currently uses the previously supplied `a65407112-boop/FunCombatAssets`, branch `main`. These files have not been uploaded by this build; that URL is a destination, not a claim of an existing deployment.

Run the local loader through a compatible executor only after the matching server place has been imported and started. It verifies protocol version, checks module dependencies, fetches raw GitHub files with bounded retries, and reports the failed path if initialization fails. It needs `loadstring` and HTTP GET. It does not require executor filesystem or model-deserialization APIs.

Assets load through typed JSON and `Instance.new`; `.rbxmx` companions preserve Roblox model data for import/inspection. The loader does **not** pretend that a model file is executable. Combat poses use original stored CFrames. Roblox-hosted mesh, texture, movement-animation and audio payloads still need access in the target runtime. MeshPart fallback retains the original MeshId but lacks PBR SurfaceAppearance. Other legacy differences are listed in `config/compatibility.json`.

Controls: choose a weapon in the original interface; left click/tap attacks; Q or the mobile Dash button dashes; G recovers while downed and otherwise starts the first custom emote; H/J/K/L select the others. E/T hold the actual server prompts for execution/carry/drop as displayed. Backspace also requests dropping. The server determines whether any request succeeds.

Read `docs/installation.md` and `docs/architecture.md`. No Roblox engine, multiplayer session or Pekora/Caelus client was available for testing. Offline syntax/structure/state-machine checks must not be confused with an in-engine playtest.
