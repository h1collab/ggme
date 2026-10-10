# Backrooms / Night Relay — Android v0.11.0

An original, monster-free atmospheric survey game by Zorix GAme Team. The current Android main scene is `faceless2/main.tscn`, which loads `backrooms.gd`. Previous forest/combat source files are retained as history in the repository but are not copied into or packaged with this build. No hostile NPCs, jump scares, weapons, creature sounds or generated character GLBs are used.

## Play

Three connected, walkable layers: yellow wallpaper/carpet offices, concrete maintenance corridors, and tiled shallow-water pool rooms with barrel vaults. Each layer has a three-minute 02:00–06:00 shift. Repair three breaker cabinets, correctly report three fluorescent circuit faults through actual live 3D surveillance feeds, then walk to the transfer lift. The final layer completes the survey.

The FNAF-inspired part is observation and limited power: shutters reduce interference but draw more power; lighting, cameras and ventilation consume reserve; backup charging adds heat and has a cooldown; false reports cost 6% power. Nothing pursues or attacks players. Power exhaustion and saturation show a calm restart screen. Solo menus pause the shift; cooperative menus leave the shared shift running.

Keyboard: WASD, Shift, E, F, Escape. Android: left joystick, right-side drag to look, independent multitouch USE/TORCH/RUN buttons. Display settings preserve menu resolution while offering Performance 60%, Balanced 80% (default), and High native 3D resolution with corresponding shadow/MSAA budgets. Sensitivity and quality are saved locally.

## Direct P2P cooperative play

Godot's native ENet/UDP, up to four players, one player acts as the host. No external account, API key, matchmaking or relay service is required. Default port is **24711**, configurable in the lobby; optional room key and version handshake reject incompatible rooms. Android INTERNET permission is enabled.

- Same network: host a survey, open Session Details to find the host's local address, and join that IP and UDP port.
- Internet: the host can request UPnP mapping on a background thread or manually forward that UDP port, then share a reachable public address. UPnP support and a public endpoint depend on the router/network. Carrier-grade or symmetric NAT may prevent direct connections; this build does not claim universal NAT traversal or provide a TURN relay.
- Host owns clock, power, doors, repairs, anomaly reporting and layer transfer. Clients send rate-limited intentions; repair/transfer/console proximity and finite/bounded movement are validated. Poses use a separate unreliable ordered channel; shared state and actions use reliable channels. Late join receives the current state. Disconnect removes crew; host loss returns clients to the lobby. There is no host migration.
- UPnP is opt-in, temporary one-hour lease; leaving attempts removal off the main thread. Mapping failure leaves LAN hosting usable. Mobile suspension or unreliable networks may require reconnecting.

Official references: [Godot ENetMultiplayerPeer](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html), [high-level multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html), [UPnP](https://docs.godotengine.org/en/stable/classes/class_upnp.html). Native WebRTC would additionally require an extension and a signaling/relay deployment, so this release uses native direct hosting.

## Branding

The supplied first image is the game icon; the second is the team logo and boot splash. Intro: **Made By Zorix GAme Team**. About Us links to **https://zorix.it**. Original source images are preserved in `branding/`.

## Build and verification

`.github/workflows/faceless2-apk.yml` restores the SHA-verified Godot base, replaces the original scripts/assets/audio with the new Backrooms project, generates three original machinery/footstep WAVs, installs Godot 4.7.2 and Android SDK, runs actual engine gameplay and four-process ENet checks, captures eighteen actual Mobile Vulkan views (including all nine surveillance feeds), and exports `backrooms-v11-zorix.apk`. The exported APK is then installed and operated on an Android 35 emulator: touch movement, live monitoring, real APK-to-desktop ENet joining, shutter replication and disconnect are checked before delivery. CI fails on missing PASS markers, engine errors, failed UDP checks or missing screenshots.

The gameplay suite exercises three-layer objectives, false-report costs, cooldowns, physical shutter blocking/headroom, boundaries, movement, progression, resource failure/restart, layout and monitoring lifecycle. The network suite uses separate host, client, late client and wrong-key client processes over real localhost UDP; it checks handshake, shared actions, rejected distant repairs, movement, layer reset, late-join state and disconnections. Screenshots cover branding, menu, guide, each layer, live monitors, lobby and completion.

This is an Android debug test APK (0.11.0 / code 11). Each workflow generates a debug signing key; installing over an older differently signed APK can require removing it first. A persistent production key/release signing and physical-device touch/performance testing remain release work. Desktop software Vulkan, Android emulator touch/ENet checks and localhost UDP tests do not establish physical Android hardware FPS or cross-network NAT behavior. The architecture, materials and simple crew avatars are original procedural game assets; this is a playable prototype progressing toward higher production quality, not a commercial AAA asset pack.
