# Installation status and steps

The full package includes the matching `FunCombat_Server.rbxlx`, client and builder. The original place remains untouched. Offline checks are recorded in `Validation_Report.md`; actual engine testing remains necessary.

1. Import the updated protocol 3 `FunCombat_Server.rbxlx` into the intended Studio/server environment. An earlier protocol 2 place will be rejected by this client. Verify both original map templates, the active Crossroads map, terrain, collision and spawn heights before publishing.
2. Upload all files from `GitHub/` to the configured repository root, retaining subfolders. Do not upload a surrounding `GitHub` folder unless CONFIG/path handling is adjusted.
3. Set Owner, Repository and Branch only in `loader.lua` CONFIG if using a different repository. Existing values identify `a65407112-boop/FunCombatAssets`, branch `main`.
4. Join the matching server. Execute `loader.lua`. A normal raw entry point, after upload, is `loadstring(game:HttpGet("https://raw.githubusercontent.com/" .. owner .. "/" .. repository .. "/" .. branch .. "/loader.lua"))()` using your configured variables. This requires an executor that exposes that HTTP API; executing the downloaded loader itself also supports request/http_request/syn.request.
5. Read initialization errors and asset warnings. The name of a failed resource is included. A missing Remotes/Version means the server is not this protocol; the loader stops after a bounded wait.
6. Check that encoded prompts show their original text only after this client loads. Test two separate clients, then test carry/execution disconnects, walking during carry and after drop, late joining, respawn and a second loader run. Check the original Gender/Info labels and `/e` commands. These in-engine checks have not been performed in this environment.

No owner/admin access is granted by the runtime. Client requests never contain damage or selected attack victims. Reexecuting destroys the previous local runtime before rebuilding interfaces and connections.

The builder is pinned to the original source checksum. Keep the original file separately; rebuilding requires it plus Python dependencies and rbxmk. Do not overwrite the source with a generated file.
