# Client world and waiting room

The external loader downloads the visible maps from this repository. Ordinary
joins spawn in a closed, unlabelled waiting room with a real floor. After the
loader has successfully initialized and mounted the current map, the server
places that player at an existing map spawn. Loader clients locally hide players
who have not joined the loaded world. Morph implementation and assets are out
of scope and must not be inspected or changed.

The server retains the original invisible collision geometry and world triggers,
so authoritative movement, landing and shared map changes keep working. This is
the implementation choice: purely local collision would not give the server the
same physical world. Visible native geometry is exported without scripts to
binary model packages on GitHub and imported by the existing asset loader.

A separate server session module validates build/map revisions, chooses existing
spawn points, maintains participation across respawns and moves disconnected
sessions back to the room. A client module mounts the selected map, handles map
changes, mirrors moving environment parts and restores locally hidden players
when unloaded. Failed or stale loads never authorize map entry. Saved eligible
instance names remain opaque; readable names are restored locally by the loader.

This does not publish the place to Roblox. Roblox Studio, actual executor
compatibility and multiplayer physics require a live test; offline results must
not be presented as engine verification.
