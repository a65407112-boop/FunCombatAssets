# Single saved rig and external presentation

The requested result is the original FunCombat game, with its map, physics,
spawns and authoritative gameplay in the published place, and original
presentation loaded from the public FunCombatAssets repository. The user
authorized implementation and requested actual files rather than another
planning handoff. No model geometry inspection is part of this work.

The saved place contains exactly one character Model outside the original
map and environment: the original StarterCharacter. Models within the
original maps/environment remain intact. The original initial DUMMY and
spawnable DummyRig become typed server data, reconstructed by RigFactory
at runtime. They remain distinct original rigs; neither is substituted
with a generic dummy. Runtime player, NPC and temporary head donor Models
are allowed. The active Crossroads map is saved once; its pristine backup
is cloned before voting begins. The other original map remains available.

All original 129 presentation packages and 47 KeyframeSequence animations
remain external. MeshPart, SurfaceAppearance and UnionOperation packages
use their original model export through a bounded local model import.
Other packages reconstruct Instances, writable properties, attributes,
parents and references from typed JSON. No replicated native presentation
constructor remains in the compact place. Import capabilities and actual
model counts are checked before the game UI starts. An unavailable native
import fails clearly; it does not substitute geometry or silently load a
server copy. Native player avatar appearance and map/environment physics
assets remain engine/server responsibilities.

Saved server containers/modules, prompt labels and network IDs are opaque.
Non-engine map/object bindings and runtime statistic names are encoded.
The external identifier manifest restores presentation/stat labels locally.
The literal leaderstats container and engine character/body/joint names
remain valid. Original Kohl Settings and Custom Commands names are kept
for the upstream API; its loader name is encoded. Attribute bindings used
by this game's client/server remain identical in the generated sources.
Server Sources have comments removed and literals pooled as encoded bytes,
without a VM, loadstring or increased script permissions. Public mappings
are reversible obfuscation, not secret encryption or moderation protection.

Protocol 5 rejects a mixed server/client build. A wire codec encodes
original presentation resource keys and map names while preserving
Instances, numeric IDs, timestamps and authoritative state. The client
decodes broadcasts and snapshots before existing runtime modules consume
them, and encodes action resource keys before sending. Only the server
chooses hits, damage, cooldowns, targets and gameplay results. Snapshot
buffering, respawn cancellation and interaction cleanup stay in the
existing audited runtime. Relevant presentation events reference external
animation/audio/effect keys; requests with no original presentation do not
invent a replacement animation.

The R6 adapter retains BodyPartDescription colors while clearing custom
body AssetId/Instance fields. Dynamic head texture, PBR, FaceControls and
original head metadata remain untouched. The same path applies to user-ID
dummies. Per-limb colors, including deliberately black parts, are preserved.

The builder accepts only the provided original source checksum, preserves
that source, and produces binary/XML server places, the GitHub tree and
archive, a complete builder/source archive, loader, installation guide and
verification report. Owner/repository/branch settings stay at the top of
loader.lua. Publishing uses a guarded atomic GitHub ref update.

Verification covers all original exported package memberships/references,
no extra saved character Models, no replicated presentation constructors,
opaque network/prompt/stat bindings, original spawn and six-motor rig
integrity, source-literal roundtrips, wire codec behavior, and bounded
native import behavior. All readable and packed server sources compile;
the binary place is decoded independently and rechecked. These checks
are separate from Roblox engine/rendering, asset permissions, executor
model support and old-client compatibility, which remain untested here.
