# Faceless 2 standalone FPS / headless network notes (v0.31)

The FPS playfield is **one independent empty 48m x 48m open area** made of 16 licensed Kenney CC0 floor GLBs plus physically invisible walls. It is not Level 2 and does not contain elevators, story objectives or passive Backrooms entities. Legacy source is kept for regression but is not a prerequisite to playing an FPS match.

## Controls and source

PC: WASD / Shift / Space to move, LMB shoot, RMB ADS, R reload, mouse to look. Android: movement joystick, RUN, JUMP, FIRE, RELOAD and swipe-to-look. The held first-person rifle is the source-verified **Kenney Blaster Kit blaster_f.glb**, not a runtime-created visible primitive. Recoil and walking sway apply to its camera pivot. Headless checks do not measure Android frame rate or cinematic quality.

## Network version and authority

Native ENet/UDP gameplay protocol is **18** (default UDP 24711), room discovery protocol version **18** (LAN multicast/broadcast + optional HTTPS Node room directory). The explicit version change is mandatory because validated pose RPCs include camera pitch and combat-state RPCs include host-owned reload/reserve state. v17 clients must not join v18 rooms.

A room can hold 2-4 connected players. One player waits; combat starts at two, even in a room with three or four seats. Losing the second player returns to waiting. Late joins and disconnects broadcast the current combat roster to all authenticated live peers. Seat numbers are allocated separately from ENet IDs, reclaimed on disconnect and used for respawns. Repeated handshakes cannot refill health/ammo. The host owns health, ammo, kills, respawn location and accepted fire rate, validates membership on every firing/reload RPC and checks ray LOS/shot yaw/pitch against the last validated peer location. Clients cannot submit direct target damage or scores. Snapshots for joining clients contain their actual assigned spawn and current combat state. Hit positions are only approximated from host-validated player movement; full lag compensation and full adversarial anti-cheat remain future work.

The QUICK MATCH UI discovers available public/LAN rooms first, then joins one with a free slot or creates a four-player host. Eight-character room codes are also supported. The optional JavaScript room directory is **not** a UDP relay and does **not** solve NAT traversal. Public internet play requires a deployed reachable HTTPS directory plus a reachable host UDP port/working mapping; otherwise match locally on compatible LAN.

## Validation and limits

CI uses real independent `godot --headless` ENet host/client processes, including late joins, wrong keys, disconnect/strong kill, room directory over Node, and remote FPS shot -> authoritative ammo -> client state replication. The authorized xvfb Godot 4.7.2 desktop workflow records actual continuous frames into H.264 (no slides). Android APK export is a build operation; no emulator/device execution or real-phone FPS claims are made. Do not declare PASS before the matching latest SHA workflows complete.

The viewmodel uses independently compacted original WRAD forearm/hand GLBs.
Socket error is recomputed from imported Skeleton3D transforms; skin contact
is measured from the actual source vertices and bind matrices. The regression
detaches a hand by 10cm to verify the measurement detects displacement. Both
hands and gun inherit ADS/recoil/movement together. Native captures include
walking, running, landing, reload and boundary retraction.

Protocol 18 synchronizes authoritative reserve ammo and reload countdown. Reload
takes 1.65 seconds, cannot be spammed to instantly refill, and blocks host-side
fire until completion. Direction must agree with the last validated yaw/pitch;
full client trust, transport security and lag compensation remain out of scope.
`test_fps_sessions.py` additionally exercises 2/3/4-seat FPS rooms through Node
and independent headless Godot UDP processes: unauthorized pre-handshake fire,
duplicate fire, forged direction/position, late joining, full-room refusal,
graceful reconnect, killed clients, return to waiting, and host loss.

SceneMultiplayer's automatic client-to-client peer relay is disabled before
connections are opened: every gameplay message uses the authoritative host.
This avoids engine relay notifications to concurrently closing transports.
The native preview job also preserves the actual licensed source project as a
separate artifact for reproducible local **headless** diagnosis. It contains no
API credentials; its BUILD_SHA.txt identifies the source revision.
