# FunCombat executor-side conversion

The user's supplied specification is the design authority. Use the attached
`FunCombat_Renamed2.rbxl` (SHA-256 a14ab714b5b3233a8e05fc5567ce1b9a7dc700ced2ccb2e13771c025f64142b0)
and repository commit a0fd9dea4b93147ecbcbfed54314abb3df8787fb. The file matches
the exact source of the existing client. Do not inspect or compare model geometry.

Keep the original two maps, physical character rigs, spawns, environment and
required character ProximityPrompt templates. Rebuild the authoritative server
from the actual source constants and gameplay flow. Export presentation before
removing its server copies. Retain Roblox engine character names. External JSON
reconstruction and original content references remain the presentation backend.

Protocol 4 encodes network object names, action/event identifiers and prompt
labels. Only the external manifest contains the semantic network mapping. The
server stores numeric action dispatch and event identifiers. Match the exact
build identity before any client initialization. Snapshots and presentation
messages carry monotonic revisions. Register listeners before initial snapshot,
buffer messages during bootstrap, resnapshot after local respawn, and destroy
all generated state when the loader is repeated or initialization fails.

Implement combat combo 20/20/40, original startup/active frames, stun, counter
presentation, downing, recovery, R6 ragdoll, carry/drop, both executions,
killstreak awakening, regeneration, emotes, Gender/Info/Admin, voting, weather,
TV, teleport pads, killboxes, rotation, music, dummy commands and secret door.
Server validates each request and prompt hold, distance and ownership. Dummy
cap: 4 per player, 20 globally, 3-second cooldown. Third-party admin loaders
are archived with their original settings because their required hosted code is
absent from the place; retain the original built-in admin allowlist. Include
original NewMorphs, all paired animation sets, sounds, wall prompts, meter,
speed controls and Completions. README is not a scope authority. Do not invent substitutes.

Output: funcombat_server.rbxl, Game_Server.rbxlx, Game_GitHub.zip, Game_ExecutorSide.zip, loader.lua,
Russian installation instructions and validation report. Builder must fail
closed on a different source, preserve input, export typed assets, assemble
place and deterministic archives, and validate structure/references/protocol.
Static syntax, package and policy tests are separate from Roblox engine tests.
Neither Roblox Studio nor an executor session is available. Legacy compatibility
and hosted asset permissions remain explicitly unverified.
