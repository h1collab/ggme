# Faceless 2 standalone FPS / headless network notes (v0.33)

The FPS playfield is **two independent 48m x 48m FPS maps**, Cargo Courtyard and Maintenance Hangar. Both use 16 licensed Kenney CC0 floor GLBs, authored Kenney structural/cover GLBs, original Poly Haven scanned props and source-verified PBR textures. Courtyard is open with loading bays; Hangar has original GLB roof wings, an open skylight, pillars, service consoles and warm source lamp fixtures. Invisible collision proxies match visible structures. It is not Level 2 and does not contain elevators, story objectives or passive Backrooms entities. Legacy source is kept for regression but is not a prerequisite to playing an FPS match.

## Controls and source

PC: WASD / Shift / Space to move, LMB shoot, RMB ADS, R reload, mouse to look. Android: movement joystick, RUN, immediate touch-down JUMP, held FIRE, held ADS, RELOAD, PAUSE and swipe-to-look. Separate pointer capture supports movement/look/aim/fire/sprint together. Releasing outside or opening a menu clears held input. Real headless viewport touch tests check three landscape aspect ratios; this is not Android device execution. The held first-person rifle is the source-verified **Kenney Blaster Kit blaster_f.glb**, not a runtime-created visible primitive. Recoil and walking sway apply to its camera pivot. Headless checks do not measure Android frame rate or cinematic quality.

## Network version and authority

Native ENet/UDP gameplay protocol is **19** (default UDP 24711), room discovery protocol version **19** (LAN multicast/broadcast + optional HTTPS Node room directory). The explicit version change is mandatory because validated pose RPCs include camera pitch and combat-state RPCs include host-owned reload/reserve state. v18 clients must not join v19 rooms. The join RPC now carries the host-selected map ID; combat and world snapshots also carry that ID.

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

Protocol 19 synchronizes authoritative reserve ammo and reload countdown. Reload
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

Host-only hit serials are optional protocol-19 combat snapshot fields; only accepted damage yields a hit marker. HP loss gives a short screen-edge flash. Read-only live kills/HP scoreboard uses host-assigned seat numbers, desktop TAB or mobile score-card tap. Compact map/room card, centered dynamic reticle and actual stamina bar preserve separate mobile look and action zones.

Quick match is single-flight and cancellable, awaits actual HTTP discovery, prioritizes occupied joinable rooms with random ties, resolves the published code, retries up to three endpoints with bounded lookup/UDP deadlines, then registers a host. Search cancellation prevents delayed room creation. Listings show map/capacity/code. This improves direct-room selection and error recovery; it is not a UDP relay or public NAT traversal service.

Desktop medium/high now render at native 3D resolution with 2x/4x MSAA; low and Android adaptive presets remain available. Sun shadow bias is reduced and original source service pipes/stock fill hangar bays without obstructing spawn lanes. All source GLB/PBR/HDR checks remain enabled.

Headless regressions measure actual accelerated movement, rapid mouse taps, five-pointer controls, scoreboard input and host cadence using monotonic wall time. Separate UDP/Node sessions cover failed-first endpoint retry, duplicate quick-match clicks, cancellation, authoritative hit confirmation and the retained six map/capacity matrices. Native desktop acceptance and APK must correspond to the new submitted SHA before delivery.

Native screenshot settling uses 20 frames at fixed 30Hz (~0.67s); bounded capture/video timeouts account for native-resolution MSAA on the CI software renderer. Recording FPS is not an Android performance measurement.

Exhausted FPS sprint has 5%/25% hysteresis: exhaustion locks sprint until meaningful recovery instead of alternating walk/run at the 5% boundary. Respawn resets the lock. A real input/physics regression reproduces the previous jitter and verifies recovery/resume; historical exploration behavior remains unchanged.

FPS fixture shutdown returns its physics-query/Shape3D locals before a separately deferred cleanup/quit phase. Verbose CI logs identify any resource lifetime failures; strict ERROR/FAIL checks remain mandatory.
