# NULRYTH v0.45 / illustrated S1 and real-map reveal (protocol25)

Built-in image_gen supplies four monochrome anime illustrations in ui_art/; PROMPTS.json preserves the complete prompts. The S1 key art becomes the manual's portrait sidebar; token/badge/title drawings continue to represent actual cosmetic rewards. FREE claims, XP, local saves, PAID preview locks and the45-level cap are unchanged.

The map archive exposes all four existing native arenas for selected-map training. Host creation offers Random or a specific map. STATIC PASSAGE gains high skybridge/cable silhouettes, FRACTURE ROW a split overhead skyline, and ERROR CROSSING a cross gateway. These shared-cube render-only landmarks preserve ground collision layouts/spawns and static batching. Covers are illustrations, not gameplay screenshots.

The map reel cycles cached covers/names quickly, decelerates and confirms. Training enters the selected native arena at completion. Online reveal resolves only when the actual arena/authority map arrives; it never independently rolls a different network map. Cancel, timeout/error, stale resolution, skip and motion-off are explicit states. Player inputs are released during reveal. The real LAN/ENet regression now checks both independent peers' final revealed map against their actual arena map.

Android0.45.0/code45; protocol25, package id, English default and saved language choices are retained. Native stills/video include the illustrated manual, map archive, actual search and final confirmation. No Android device performance conclusion follows from headless/build/desktop validation.

# NULRYTH v0.44 / ZOrix developer branding (protocol25)

NULRYTH replaces the previous Strinova display name across launch, lobby, settings, rooms and Android. The existing ZOrix controller/Z logo is reused through a display-only grayscale material, with explicit “Developed by ZOrix” credits on launch and menu pages. The launcher uses a monochrome N mark. Android version0.44.0/code44. English default, saved language choices, package id, saves and protocol25 are retained.

# NULRYTH v0.43 / monochrome launch and S1 interface (protocol25)

The displayed game name and Android application label are NULRYTH. Settings show “NULRYTH (formerly Faceless 2)” in English and “NULRYTH（原 Faceless 2）” in Chinese. New installations default to English; explicit saved language choices remain respected. The Android package id, legacy save filenames and internal RPC node name remain unchanged; this is presentation-only and stays on protocol25.

A lightweight boot scene renders a black/white loading screen before the gameplay scene. Critical fonts/GLBs load through Godot's resource loader thread; gameplay scripts initialize on the main thread and report six completed stages. Progress is monotonic and reaches 100 only after the lobby is initialized. The old timed team splash is bypassed in this launch path. A short dark handoff replaces abrupt page flashes.

S1 reward cards use fixed title, quantity/type and action rows. Future, claimed and unowned paid actions are disabled; FREE progression/collection and PAID preview rules remain unchanged. Lobby avatar rendering waits until its camera, lighting and bones are ready. Button feedback resolves combined hover/focus/press state. Glitch accents are confined to small decorative rules with a settings toggle; body text, controls and full-screen brightness stay steady.

Android 0.43.0 / versionCode43. Desktop capture records the real boot frames plus the existing 1166-frame gameplay sequence; encoded duration varies with actual loading time. Desktop/headless/build evidence is not Android device performance evidence.

# v0.42 / S1 first signal (protocol25)

Party-style lobby: central authored character, left-side season/collection controls, right-side season summary and bottom play actions. S1 has 45 levels with FREE and PAID reward rows, XP/level progress, nine browsable five-level pages, idempotent free claims and a persistent local cosmetic collection. XP comes from actual round completion and completed target drills with hits. The PAID row is a locked preview; purchasing and verified paid ownership are not yet available. Local progression is not an account-backed economy.

Diagonal wall contact accelerates tangent movement up to 8m/s, with a 0.2s departure carry. Straight wall pressure, floors, no movement and ADS do not trigger it. Hosts independently check a nearby vertical wall plus tangent movement and retain capsule sweep/path validation. Protocol25 intentionally separates these movement rules and revised facade colliders from older clients. Deploy matching clients and room service.

All six source rigs now use a speed-matched run cycle and a non-looping jump pose selected from rise/fall velocity; landing blends back into locomotion. Remote actors infer airborne state and vertical velocity from received poses. Sparse asymmetric facade features and broken fracture seams replace repeated window grids/error bars; collidable box cover remains. Android 0.42.0 / versionCode42.

# v0.41 minimal monochrome HUD and fractured alleys (protocol 24)


The monochrome HUD consolidates match details and removes the duplicate solo title. Borderless status cards and the compact weapon bar keep the center clear; touch targets and safe-area fitting remain intact. The menu background is static except for active matchmaking. Third-person bodies use grayscale cel palettes. The anime void hands/feet and weapon finishes remain.

Third-person shoulder aim uses its own 64-degree FOV (56 for sniper), avoiding first-person 24-degree scope zoom. Camera collision fitting runs before displaying the third-person body. Separate hide/show distances prevent wall-edge visibility flicker.

This v0.41 update changes presentation only; collision and protocol 24 remain compatible with v0.40.

Four authoritative maps now use a connected urban alley layout: narrow central and side lanes, cross streets, solid buildings and stacked collidable crates. Crate/floor source GLBs and bounded static batches are retained. Building facades use one shared 12-triangle BoxMesh rather than stretching decorative floor GLBs into large solid blocks; visible architecture and collision share the same extents. Black/white fracture masks are computed in the existing opaque surface shader; no particle cloud or animated fullscreen distortion. Map-specific return walls and overhead bridges vary sightlines. All six spawn pockets and the central training lane remain clear.

First-person feet use the same anime void shader as the hands, including in FPS mode when looking down. Third-person source rigs keep their bones and animations, with texture-free cel palettes, ink outlines and seat accents. The shoulder offset blends across aim/side changes before the existing collision sweep, preserving immediate inward wall retraction and gradual outward recovery.

Protocol 24 intentionally rejects old protocol 23 clients because alley collision/layouts differ. Update the room service with the client. Android version 0.41.0 / versionCode41.

# v0.39 anime art direction (protocol 23 unchanged)

First-person hands, all four weapons (including third-person held weapons), and
all four FPS arenas now use anime styling. Guns use cel color blocks and ink
outlines; walls, floors and props use a texture-free shared palette. The sky is
a cached procedural gradient, not a photographic HDR panorama. The source GLB
geometry, skinning, grip, collision layouts and authority rules stay intact.
Source PBR assets remain licensed/provenance inputs but are not the active FPS
material finish. Do not restore realistic skin, metal wear or scanned surface
textures without a new art-direction request.

## Renderer groundwork

Spatial MultiMesh batches reuse **exact original licensed meshes** and current
anime material overrides;
24m cells preserve bounded culling, source nodes and collision proxies remain
available for parity tests. Source meshes in a batch are hidden to avoid double
drawing. The native preview compares actual GPU instance transforms with source
transforms, and records scene-only visible draw calls and frame times against
`7dbb958eaecec89573f6013836986de2b86111ed` on the same Linux runner. Headless tests
inspect the exact submitted transform buffer because the dummy renderer does not
retain GPU buffer getters. A lower submission count alone is not proof of faster
Android FPS.

On Android, presets cap 3D render pixels at 0.6 / 0.9 / 1.4 million while retaining
the full-resolution 2D HUD and touch coordinates. There is an 8s startup grace,
2.5s sustained-overload threshold, 6s resize cooldown and 12s stable recovery
threshold. Opening a menu pauses adaptation. Quality presets still control resolution, anti-aliasing and shadows. The anime
finish does not sample the former photographic PBR normal/roughness maps.
Nearby lamps fade influence smoothly with distance;
geometry and collision never disappear for this purpose. The gradient sky and shared
anime materials are cached across map changes; animation names are resolved once.
Relay Depot also gets the intended outdoor sunlight instead of hangar exposure.

**Not verified:** Android device FPS, thermal behavior, public deployment/NAT,
complete anti-cheat, AAA/photoreal quality or absence of all bugs. Native diagnostic
frame times are CI software-renderer measurements, not phone performance claims.

# v0.38 / SIGNAL · four sectors, six seats

Source protocol is **24**, incompatible with protocol 23. Four host-selected maps:
Cargo Courtyard, Maintenance Hangar, Relay Depot, Foundry Crossing. Six distinct
spawn seats on each 72×96m map; two real players start in rooms capped at 2–6.
Seats 5/6 reuse original licensed character meshes 1/2 with cyan/copper material
tints. There are four original character meshes, not six new authored characters.

Home atlas rings rotate at capped 30Hz while visible; actual search state enables
the lobby scanner. Third-person has a swept 20cm camera sphere in addition to
near-plane rays, shorter ADS boom, Q/touch shoulder switching and exponential
return smoothing. Movement adds ground snap, limited air acceleration, 100ms
coyote time and 120ms landing jump buffer. These are handling changes, not a claim
of complete physical simulation or AAA quality.

## Cross-network JS-managed rooms

The directory can now supervise dedicated authoritative `godot --headless`
processes. The game server takes **zero** seats: one client waits, two clients play,
six clients fill the room. Only fixed configured binary/project paths are run;
players cannot submit executable paths/commands. Room keys go to native stdin,
never process command lines. Startup deadlines, process count/port bounds,
empty-room expiry and shutdown cleanup bound resource use. Native server counts
populate listings; client HTTP cannot mutate or delete a managed room.

Configure/deploy using [matchmaking deployment instructions](../matchmaking/DEPLOYMENT.md).
Client creates a managed room when HTTPS `/health` reports protocol 24 and
`managed:true`; legacy direct-host/LAN rooms remain supported. A JS directory
alone still cannot relay UDP or bypass NAT. **No public service URL is embedded
or deployed by this commit.** Public end-to-end mobile/Wi-Fi testing is pending.

## Authority and limits

Host checks membership, map bounds, finite values, movement-speed budget and
swept player-capsule wall collision. Invalid wall/speed movement is corrected to
the last accepted pose. Existing authoritative ammo, cooldown, reload, weapon,
hits, occlusion, score, round/death/respawn checks stay enabled. Six-seat tests
extend the existing independent-process ENet regression rather than replacing it.

HTTPS protects directory traffic when deployed with a valid certificate. Native
ENet gameplay in this version remains **unencrypted UDP**. Packet capture cannot
be made impossible on a player-controlled device. This is not kernel anti-cheat,
full server movement simulation, ranked identity authentication or protection
against every malicious host, aim assist, fly hack or traffic attack. Production
hosting needs network/DDoS controls and operational monitoring.

Previous release notes and test scope follow for history; current protocol,
capacity and map counts above supersede earlier limits.

# Faceless 2 standalone FPS / headless network notes (v0.37)

The FPS playfield is **two independent 72m x 96m FPS maps**, Cargo Courtyard and Maintenance Hangar. Both use 48 licensed Kenney CC0 floor GLBs, authored Kenney structural/cover GLBs, original Poly Haven scanned props and source-verified PBR textures. Courtyard is open with loading bays; Hangar has original GLB roof wings, an open skylight, pillars, service consoles and warm source lamp fixtures. Invisible collision proxies match visible structures. It is not Level 2 and does not contain elevators, story objectives or passive Backrooms entities. Legacy source is kept for regression but is not a prerequisite to playing an FPS match.

## Controls and source

PC: WASD / Shift / Space to move, LMB shoot, RMB ADS, R reload, T optional solo target drill, TAB scoreboard, mouse to look, 1–4 to select weapons, V to switch perspective. Android: movement joystick, RUN, immediate touch-down JUMP, held FIRE, held ADS, RELOAD, PAUSE and swipe-to-look. Separate pointer capture supports movement/look/aim/fire/sprint together. Releasing outside or opening a menu clears held input. Real headless viewport touch tests check three landscape aspect ratios; this is not Android device execution. The held first-person rifle is the source-verified **nisu / 3DModelsCC0 M4A1**, converted from the original publisher FBX to GLB with its original PBR maps; previous Kenney weapons remain preserved. Recoil and walking sway apply to its camera pivot. Headless checks do not measure Android frame rate or cinematic quality.

## Network version and authority

Native ENet/UDP gameplay protocol is **22** (default UDP 24711), room discovery protocol **22**. v0.35 adds a reliable authenticated ready RPC and host-owned round state; v21 and older clients must not join. Pose RPCs include camera pitch; snapshots include host-selected map, reload/reserve state and assigned seats. The optional Node directory is a lookup service, not a UDP relay or NAT traversal guarantee.

A room can hold 2-4 connected players. One player waits; combat starts at two, even in a room with three or four seats. Losing the second player returns to waiting. Late joins and disconnects broadcast the current combat roster to all authenticated live peers. Seat numbers are allocated separately from ENet IDs, reclaimed on disconnect and used for respawns. Repeated handshakes cannot refill health/ammo. The host owns health, ammo, kills, respawn location and accepted fire rate, validates membership on every firing/reload RPC and checks ray LOS/shot yaw/pitch against the last validated peer location. Clients cannot submit direct target damage or scores. Snapshots for joining clients contain their actual assigned spawn and current combat state. Hit positions are only approximated from host-validated player movement; full lag compensation and full adversarial anti-cheat remain future work.

The QUICK MATCH UI discovers available public/LAN rooms first, randomly selects an available room or creates a four-player host. The host chooses one of the two maps uniformly with Crypto random bytes; joins, rejoining and late joining use that fixed authoritative map. Clients cannot change map through directory heartbeat or combat requests. Eight-character room codes are also supported. The optional JavaScript room directory is **not** a UDP relay and does **not** solve NAT traversal. Public internet play requires a deployed reachable HTTPS directory plus a reachable host UDP port/working mapping; otherwise match locally on compatible LAN.

## Validation and limits

CI uses real independent `godot --headless` ENet host/client processes, including late joins, wrong keys, disconnect/strong kill, room directory over Node, and remote FPS shot -> authoritative ammo -> client state replication. The authorized xvfb Godot 4.7.2 desktop workflow records actual continuous frames into H.264 (no slides). Android APK export is a build operation; no emulator/device execution or real-phone FPS claims are made. Do not declare PASS before the matching latest SHA workflows complete.

The viewmodel uses independently compacted original WRAD forearm/hand GLBs.
Socket error is recomputed from imported Skeleton3D transforms; skin contact
is measured from the actual source vertices and bind matrices. The regression
detaches a hand by 10cm to verify the measurement detects displacement. Both
hands and gun inherit ADS/recoil/movement together. Native captures include
walking, running, landing, reload and boundary retraction.

Protocol 20 synchronizes authoritative reserve ammo and reload countdown. Reload
takes 1.65 seconds, cannot be spammed to instantly refill, and blocks host-side
fire until completion. Direction must agree with the last validated yaw/pitch;
full client trust, transport security and lag compensation remain out of scope.
`test_fps_sessions.py` additionally exercises both maps × 2/3/4-seat FPS rooms through Node
and independent headless Godot UDP processes: unauthorized pre-handshake fire,
duplicate fire, forged direction/position, late joining, full-room refusal,
graceful reconnect, killed clients, return to waiting, and host loss.

SceneMultiplayer's automatic client-to-client peer relay is disabled before
connections are opened: every gameplay message uses the authoritative host.
This avoids engine relay notifications to concurrently closing transports.
The native preview job also preserves the actual licensed source project as a
separate artifact for reproducible local **headless** diagnosis. It contains no
API credentials; its BUILD_SHA.txt identifies the source revision.

Explicit room-code joins use the native host's actual seat limit rather than
rejecting a request from stale directory counts. Join/leave events immediately
refresh LAN announcements and directory heartbeats. UDP regressions also check
actual remote HP damage, kill/respawn score replication and timed reserve reload.
The test harness defers shutdown outside SceneTree._process and drains source
audio/resources, preserving strict no-ERROR log verification.

Near-wall QA uses an actual licensed Kenney GLB wall as a temporary capture-only
fixture. It is never added to either shipped map. Actual shipped map walls and cover are also captured. Retraction measures the
real gun vertices in its current transformed basis against the physics ray's
wall plane; headless geometry and native screenshots/video verify separately.

The scope's original opaque lens caps are removed by a fixed-source-hash baker
(12 original faces only), so ADS has an actual open sightline through the
authored GLB tube. The original source remains packaged; derivative output
hash is audited. ADS eye height follows the original optic center coordinate.

Grip anchors are projected onto real original gun triangles, not just selected
nearby coordinates. Runtime measures anchor-to-gun-surface distance as well as
socket displacement and CPU-skinned contact: limits are 0.5mm / 2mm / 5mm.
This closes the earlier roughly 10mm/17mm gaps between estimated anchors and
the actual pistol-grip/fore-end surfaces. Native views still decide acceptance.

## v0.32 visible polish and disconnect deadline

The host reclaims authenticated clients after 15 seconds without an accepted pose, using monotonic time; normal clients submit poses at 20Hz even while waiting/in menus. The original ENet retransmission timeout alone exceeded the existing 23-second strong-kill test deadline in GitHub CI. Production liveness cleanup removes the transport, authoritative combat roster/avatar/seat and refreshes discovery; the test is retained unchanged. Neither the APK nor public cross-NAT play is declared successful from local testing alone.

Central source-GLB cover islands retain diagonal spawn sightlines and a clear central lane. Rotated panel mesh thickness is centered on its physical proxy; real imported AABBs are checked against each map collider. Original pillar GLBs are fitted to structural footprints, and original lamp fixtures are mounted at their faces. Hangar uses balanced cool indirect ambient light plus warm fixtures and sun/skylight shadows. Both WRAD wrist frames are adjusted together with retained original skin/bones and measured grip contact. Four-corner SVG HUD icons show real map/room, health, magazine/reserve/reload, score and host-authorized kill events; mobile action icons preserve independent touch capture.

## v0.33 responsive combat, HUD and matchmaking

FPS-only walk/sprint is 3.8/6.2m/s; historical exploration remains 2.6/4.3. Host movement bounds follow the actual FPS sprint limit with bounded packet allowance. Local and host fire cadence uses the same 120ms interval (host tolerance 2ms). A 160ms single pending tap buffer prevents near-cooldown presses from disappearing. Holding desktop LMB and mobile FIRE repeats; opening a menu cancels pending taps. Hits remain instantaneous physics hitscan, not slow projectile flight. Gentle rig recoil is retained.

Host-only hit serials are optional protocol-20 combat snapshot fields; only accepted damage yields a hit marker. HP loss gives a short screen-edge flash. Read-only live kills/HP scoreboard uses host-assigned seat numbers, desktop TAB or mobile score-card tap. Compact map/room card, centered dynamic reticle and actual stamina bar preserve separate mobile look and action zones.

Quick match is single-flight and cancellable, awaits actual HTTP discovery, prioritizes occupied joinable rooms with random ties, resolves the published code, retries up to three endpoints with bounded lookup/UDP deadlines, then registers a host. Search cancellation prevents delayed room creation. Listings show map/capacity/code. This improves direct-room selection and error recovery; it is not a UDP relay or public NAT traversal service.

Desktop medium/high now render at native 3D resolution with 2x/4x MSAA; low and Android adaptive presets remain available. Sun shadow bias is reduced and original source service pipes/stock fill hangar bays without obstructing spawn lanes. All source GLB/PBR/HDR checks remain enabled.

Headless regressions measure actual accelerated movement, rapid mouse taps, five-pointer controls, scoreboard input and host cadence using monotonic wall time. Separate UDP/Node sessions cover failed-first endpoint retry, duplicate quick-match clicks, cancellation, authoritative hit confirmation and the retained six map/capacity matrices. Native desktop acceptance and APK must correspond to the new submitted SHA before delivery.

Native still settling uses 60 normal rig-advance steps plus eight rendered frames; continuous movie capture renders every recorded frame separately. Bounded capture/video timeouts account for native-resolution MSAA on the CI software renderer. Recording FPS is not an Android performance measurement.

Exhausted FPS sprint has 5%/25% hysteresis: exhaustion locks sprint until meaningful recovery instead of alternating walk/run at the 5% boundary. Respawn resets the lock. A real input/physics regression reproduces the previous jitter and verifies recovery/resume; historical exploration behavior remains unchanged.

FPS fixture shutdown returns its physics-query/Shape3D locals before a separately deferred cleanup/quit phase. Verbose CI logs identify any resource lifetime failures; strict ERROR/FAIL checks remain mandatory.

Quick match covers a complete 2-second LAN announcement cycle (2.25s minimum), publishes new hosts immediately, and waits only 0.5s minimum when an HTTP directory is configured. An extra real headless pair verifies UDP discovery -> room code -> authenticated ENet without HTTP, including identical map/geometry/seats. CI routes announcement datagrams to loopback and closes the host discovery listener to avoid a single-machine port conflict; physical Wi-Fi and public NAT remain unverified.

Retained legacy UDP regression waits for an actual accepted remote pose under an 8s monotonic deadline; client holds real W until the CharacterBody advances 1.2m under a 4s deadline. This replaces load-sensitive fixed sleeps while preserving the original host movement threshold, wrong-key/graceful disconnect, late snapshot and strong-kill assertions. Test fixture resources return before deferred shutdown.


## v0.34 reference-directed range and rifle

Replace the active stylized firearm with the source-authored CC0 M4A1 and original PBR maps; preserve the previous Kenney assets. Headless native FBX conversion and source hashes are mandatory in both build workflows. Original magazine and charging handle animate during reload, while WRAD hands share the gun pivot and return to their calibrated grasp.

Add numbered high range partitions, narrow GLB uprights and low approach covers, retaining all original spawn pockets and central training lane. Use warm mineral walls, a stronger directional key and brighter hangar ambient fill. Reduce the four corner HUD cards and mobile button opacity; preserve the independently captured move/look/action touch regions and actual ammo/HP/stamina bindings.

Each accepted server shot raycasts the real solid world and publishes bounded optional `impacts` combat snapshot data (protocol 20, unchanged RPC signature). Clients render each serial once, at the host's point/normal. At most 32 events are transmitted and 48 2D marks exist locally, fading after 23 seconds and removed by 25 seconds or leaving. Marks are cosmetic and cannot authorize damage. The kill feed maps IDs to actual roster seats.

Solo players may explicitly toggle **TARGET DRILL / T** from pause or the T key. A 45-second challenge uses three genuine Kenney GLB targets with ray-only collision, world occlusion and the existing host firing cooldown/ammo rules. HUD shows time, hits and accuracy; rejected requests never count as attempts. Targets react briefly to accepted hits. The solo pause stops the timer, expiry removes targets and saves the best hit score in settings, and T can restart. Targets are absent by default and cannot be enabled in multiplayer. Both two-player-start maps and the existing real six-scenario UDP matrix remain mandatory.

Still requires native visual inspection on every latest SHA. Encoding FPS is not a device-performance claim. No Android install, sustained device FPS, physical-Wi-Fi or public NAT/relay verification.

The native v0.34 image review found the old right-palm orientation still aimed along the fore-end instead of up the M4A1 pistol grip. Rotate that authored wrist frame toward the actual upright grip, preserving source bones/skin and shared-parent motion. Align the original rear peep reference at source `(-0.000824, 0.0773845, 0.066138)` (the circular rim center, not the node origin) to the camera sight axis; assert less than 1mm offset after ADS settles. Native screenshots must independently confirm the result.

Authoritative damage now uses the same upright 0.32m-radius, 1.72m-height, 0.88m-center capsule as the actual CharacterBody3D. The old torso sphere could miss eye-height/leg rays. A headless fixture compares 15 actual physics rays against the analytical capsule entry (head, torso, legs and lateral misses) within 5mm, retaining world occlusion and host-only 25 damage. The 70m virtual hitscan range covers both 48m arenas; this is a gameplay distance, not a firearm ballistics claim.

The real-process reload flood fixture sends reload plus ten fire RPCs in one client command on the existing reliable ENet channel, then checks host-side rejection count, unchanged ammo captured at rejection, host monotonic completion duration and client refill/reserve. This removes a reproduced filesystem-command scheduling race where an intended during-reload shot arrived after reload completed. It retains all ten real RPCs and every gameplay property; no cooldown/authority/error gate is relaxed. The three bounded per-member diagnostic dictionaries are never client-authoritative and are reclaimed with the roster.

Close-wall extent calculation caches 104 original mesh-bound corners rather than transforming all 10,480 imported vertices on every close-wall frame. These conservative per-part bounds must contain every actual weapon vertex under four different rotations; the real physics-wall/source-vertex check remains mandatory. A headless CPU microbenchmark prints both paths' timings, which measure this calculation only, not GPU/device FPS.

The original WRAD forearms are rigidly aimed down beyond the view; the authored wrist is counter-rotated to retain the complete calibrated hand frame. Runtime guards check wrist position/orientation and bone length. Godot 4 local bone pose already contains rest; applying rest twice had caused incorrect joint compensation. This numerical guard still requires native screenshots and continuous-video review for visible wrist/stock intersections.


## v0.35 round rules and visual refinement

Two authenticated peers immediately start the host's five-minute monotonic
clock; fewer than two pauses it and locks fire. First to ten kills or timeout
ends the round, locks fire/reload, displays all tied winners, and preserves the
winner seat labels if a player leaves. Eight seconds later the host resets HP,
magazines, reserve, scores, reloads, impacts and spawns. All current members can
ready earlier (desktop Enter or the touch result button). Duplicate, unauthenticated
and live-round ready requests are rejected. Late joiners receive current round
state; disconnects remove readiness. This is free-for-all, not ranked matchmaking.

The existing real headless UDP matrix now validates end-round state, locked fire,
late join during intermission, authenticated readiness and rematch reset on both
maps / all 2, 3, 4 capacities. The 2-player courtyard case scores ten actual kills
(40 accepted rays plus actual reload), then tests timeout draw and automatic
rematch. A fixture-only host timer shortening exercises timeout; clients never
supply a clock or score. One-player clock pause is checked separately.

The WRAD CC0 hands use an explicitly source-derived offline rounded surface
(see credits), not a new unlicensed model. Close-wall fitting uses actual hit
planes and cached original rifle bounds to turn sideways between the wall and
camera near plane, retaining a visible weapon without scale animation. Tests
inspect every original firearm vertex against straight/oblique physics walls;
this geometric fixture does not establish no clipping in every possible pose.
Material scale, neutral concrete tint and hangar light balance are adjusted.
A native Linux capture and MP4 are required before visual approval. Android
hardware FPS, public NAT, production matchmaking and full anti-cheat remain
unverified. This release is not represented as AAA quality.

Native v0.35 review also exposed a floating reload fist. Calibrate a contact on
the original M4A1 magazine-base triangles; first reach its stationary base,
then move the original magazine and hand together through withdrawal/insertion,
and return to the fore-end before animation completion. Check the actual
skinned skeleton socket against the moving source-mesh point at five phases;
a real 10cm hand perturbation must fail. CPU-skinned palm vertices must also
stay within 5mm of contact, and the actual contact must project inside the
viewport at all five phases. Raise the rifle during reload to keep its magazine
and supporting hand visible. Leaving mid-reload restores the magazine, handle and
hand transforms immediately and clears action timers. Capture an extra contact-phase
PNG for each map. This remains a simplified base-supported reload, not a claim
of motion-captured animation or a physically simulated magazine inventory.


## v0.36 combat update (protocol 22)

- Press V / touch THIRD to toggle shoulder camera. The first-person view remains available. Five physics rays retract the shoulder camera; all shots originate at the player's body eye, with a second world-occlusion ray. Camera position never determines the authoritative muzzle.
- Keys 1–4 / four touch slots choose M4A1, sidearm, sniper and knife. The server owns selection, magazine/reserve, cooldown, damage, melee range and reload. Separate inventories survive switching; 250ms equip delay and the old weapon cooldown prevent cycling exploits. Malformed/unknown/reloading/result-state requests are rejected.
- Rifle: 24/120, 25 damage, .12s cadence. Sidearm: 12/72, 34 damage, .20s. Sniper: 5/25, 100 damage, 1.05s. Knife: unlimited, 50 damage, .45s, 2m occluded reach. Reload times 1.65/1.25/2.50 seconds. Source-model shapes are stylized except the inherited authored M4A1; extra-weapon reload is a simplified carry motion.
- Four distinct licensed skinned models are chosen deterministically by authoritative seat; original locomotion/action clips are preserved. This is not a custom photorealistic animation set.
- Both maps now measure 72×96 metres, with 48 imported floor panels, alternating sector walls, returning cover pockets and flank routes. The original central test lanes remain. Spawn positions remain in clear central pockets to avoid excessive travel with two players.
- Left upper HUD: kills, deaths, score (100 per kill). Bottom: real HP and stamina bars, actual ammunition, selected weapon. Five-minute host clock / first to ten kills; final ranking sorts kills descending, deaths ascending, seat ascending for deterministic ties; equal kill counts remain a draw. Auto rematch / authenticated readiness retained.
- Offline deterministic synthesized weapon, switch, damage, result and reload sounds. Remote shots are spatialized with bounded player pools. These are synthesized Foley, not field recordings. Native preview movie has no recorded audio track.
- Android physical device, sustained device FPS, Wi-Fi/public NAT, full anti-cheat and AAA quality remain unverified. Automated game tests are Godot --headless; native screenshots/movie use the user's explicit Linux+xvfb exception only.

The v0.36 UDP harness prepares the late-join lobby process before expiring a
round, then joins through the real directory and ENet during intermission. This
keeps slow process startup outside the eight-second observation window without
changing the game clock or late-join assertions. Shutdown cancels discovery,
stops/unloads audio, drains deferred deletion and 250ms of monotonic time for
the audio thread, then quits from a separate deferred function after the drain
coroutine returns. Strict resource/error checks remain enabled; verbose peer
logs preserve any future leaked-resource identities.

## v0.37 SIGNAL interface
Original code-native navy/cyan/yellow visual system replaces default button,
focus, disabled, input and settings marks; white primary / cyan secondary text
retains full opacity in unselected weapon slots. Original vector sector atlas
on the bilingual title screen is an abstract map illustration, not gameplay.
HUD layouts and weapon styling rebuild only on state changes; live ammo,
health, reload and reticle still update normally. Three-aspect-ratio real touch
regressions and a 300-refresh stable-state check are retained. This reduces
HUD work, not a claim of measured Android GPU or sustained frame rate.
