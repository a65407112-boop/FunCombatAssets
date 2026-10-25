# Native blocky R6 and runtime names

- Remove the saved StarterCharacter; enable native R6 appearance and dynamic heads.
- Strip only non-head R6 CharacterMesh body packages, including late arrivals.
- Preserve current player morph/head/facial data instead of refetching account appearance.
- Keep native Animate and morph-owned tracks; retain fallback for characters without it.
- Rebind in-place R6 body changes without teleporting, losing weapon/cooldown or retiring the live character permanently.
- Retain all 338 map/environment models and save the two distinct NPC templates.
- Use opaque saved names; restore normal client-visible names only when the external loader runs, including late replication and reload cleanup.
- Preserve opaque map properties/references through binary roundtrip and keep manifest/server build identities matched.

Base: repository server at c10245231cc4decc05cc3b8f7cfa7ec7a9a92986. The reattached FunCombat_Renamed.rbxl was unavailable. Roblox Studio/multiplayer/dynamic-head rendering have not been run here.
