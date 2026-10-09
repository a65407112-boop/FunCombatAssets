# R6 body-color correction

This release preserves each player's original torso and limb colors while
retaining the native dynamic-head adapter. User-ID dummies use the same
appearance preparation and preserve their own palette, including intentionally
black body parts.

## Cause and change

The R6 adapter previously destroyed non-head `BodyPartDescription` children
after clearing custom body asset IDs. Roblox's upgraded description API
synchronizes child changes back to the corresponding `HumanoidDescription`
properties. Deleting those children therefore also removed body-color data;
the retained head description kept its color.

The adapter now retains non-head description children and their `Color`, but
clears `AssetId` and `Instance`. This prevents custom body packages from
replacing the original R6 rig without deleting the user's palette. Head
metadata, original native texture/PBR, facial controls, bones, attachments,
and the head-loading path are unchanged.

Roblox API reference:
https://devforum.roblox.com/t/upgraded-humanoiddescription-api/3105706

## Install

Publish the matching rebuilt `funcombat_server.rbxl` or `Game_Server.rbxlx`
to your place, then join a new server and run the matching external loader.
Updating GitHub alone does not replace the Avatar module in a running server
or an older published place. Preserve the source file separately.

## Verification and limits

The regression tests first reproduced three failures in the old adapter.
All 24 Avatar scenarios passed after the correction, including distinct
per-limb colors, a genuinely black limb, user-ID dummies, native dynamic
heads, classic heads, respawn cancellation, and asset deadlines. All 19
offline test suites passed. The rebuilt place is decoded and its embedded
Luau sources compiled separately from the template tests.

These are static and mocked-service checks. Roblox Studio, live Roblox
rendering, phone/PC executors, and legacy client compatibility were not
tested. No model geometry was inspected. The separate `diagnose.lua` remains
available for an in-game snapshot; diagnostics are not part of the loader.

The protocol-5 single-saved-rig project includes this correction. Its layout
and external-model-import requirements are documented in installation.md.
