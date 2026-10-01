# Fun Combat — external combat client (assembled combat build)

This repository contains real source-derived asset packages and an implemented external client. **It is not a verified playable release.** The matching `FunCombat_Server.rbxlx` is included in the full project package; its structure is checked offline. This loader does not work against the unmodified original place.

The source used for this build is `FunCombat_Renamed.rbxl`, SHA-256 `a14ab714b5b3233a8e05fc5567ce1b9a7dc700ced2ccb2e13771c025f64142b0`.

Included: six original weapon models and attachment data, 23 stored combat/carry/execution/awakening/custom-emote sequences, seven built-in chat emotes with 13 original hosted AnimationIds, original GUI/effect/audio/weather data (including Gender and Info), server state rendering, R6 locomotion, input, native prompts, voting, respawn binding and idempotent cleanup. The explicit sexual-interaction branch is excluded. Prompt names and visible labels are deterministic opaque codes. The external client restores readable labels locally; source map and asset names are preserved.

The one repository configuration is `CONFIG` at the top of `loader.lua`: `a65407112-boop/FunCombatAssets`, branch `main`. To use another repository, upload **this folder's contents**, with `loader.lua` and `manifest.json` at repository root, then update CONFIG.

Use the newly supplied **protocol 3** `FunCombat_Server.rbxlx`. The previous build had a startup defect: Main expected version 2 although the place declared version 3. This is corrected in the new server; replace the previous place even if it already declared version 3. See `docs/restoration.md` for the exact additions and remaining exclusions.

Run the local loader through a compatible executor only after the matching server place has been imported and started. It verifies protocol version, checks module dependencies, fetches raw GitHub files with bounded retries, and reports the failed path if initialization fails. It needs `loadstring` and HTTP GET. It does not require executor filesystem or model-deserialization APIs.

Assets load through typed JSON and `Instance.new`; `.rbxmx` companions preserve Roblox model data for import/inspection. The loader does **not** pretend that a model file is executable. Combat poses use original stored CFrames. Roblox-hosted mesh, texture, movement-animation and audio payloads still need access in the target runtime. MeshPart fallback retains the original MeshId but lacks PBR SurfaceAppearance. Other legacy differences are listed in `config/compatibility.json`.

Controls: choose a weapon in the original interface; left click/tap attacks; Q or the mobile Dash button dashes; G recovers while downed and otherwise starts the first custom emote; H/J/K/L select the others. E/T hold the actual server prompts for execution/carry/drop as displayed. Backspace also requests dropping. The server determines whether any request succeeds.

The original Gender selector saves one of Male/Female/Fembxy for the current session and displays it in the original Info nameplate. Chat supports `/e wave`, `/e point`, `/e dance`, `/e dance1`, `/e dance2`, `/e dance3`, `/e laugh`, `/e cheer` and the original `/emote` prefix. Moving or entering combat interrupts an emote. The carry pose allows walking legs; drop resumes movement without requiring a fresh Running event.

The original `Admin` panel and `BillboardGui` OWNER label retain their source names and appearance. Admin commands are available only to the original `GuardianWorld`, `ghuisehgfrshdsrgsdd`, and `Roblox_ovovo` usernames; the server checks each request. The OWNER label belongs to `DeluxeyThaLux` independently of admin access. These are source identities, not the GitHub account owner. The allowlist is in the server-only `Rules` module. Kick, Kill, NoRespawn, both tabs, window dragging, profile information and RIX toggle are wired. NoRespawn blocks replacement characters until the target leaves the server; ambiguous or empty usernames are rejected.

Read `docs/installation.md` and `docs/architecture.md`. No Roblox engine, multiplayer session or Pekora/Caelus client was available for testing. Offline syntax/structure/state-machine checks must not be confused with an in-engine playtest.

Upload your own ordinary costumes named `pp` and `Boba` to `imports/outfits`.
Their Instance names are preserved. Legacy `boba`, `LowerRig` and `TorsoRig`
inputs are also accepted; keep only one source file for each costume slot.
The **Import own costumes** GitHub Actions workflow prepares them automatically;
there is no in-game importer. The optional client controller
attaches accessories/clothing to R6 using authoritative Gender state, restores
them after respawn, and removes them on reload. No costume models are prefilled.
This is independent of the excluded interaction and its animations; it adds no
combat actions. Follow [the import instructions](docs/custom-outfits.md).
