# Backrooms Night Relay — 0.12.0 / code 12

## Setting and progression

You are a Zorix anomalous-building maintenance investigator following Lin Lan's emergency signal into a building that no longer exists. Once the maintenance door closes, the exit disappears. Each of three floors brings a separate Chinese briefing, log clues, subtitles, a directional objective and a short staged sighting of an authored GLB creature emerging from and retreating behind a wall. Sighting events are locally scripted once per floor; they do not alter the host's shared resources or remotely steer another peer's camera. The auto-turn is optional, smoothed and manually interruptible, with a short temporary movement hold; testing on real devices remains outstanding.

The office, maintenance and pool levels have distinct floor and wall surfaces, workstations and ambient audio. Gameplay is centered on cameras, repair, power, heat and interference rather than shooting: restore all three relay cabinets, correctly report three surveillance-light anomalies, keep the shift operating from 02:00 to 06:00, then reach the transfer elevator. Failed reports cost power; electrical isolation gates and emergency charging consume or heat systems. Solo menus pause, while co-op shared time continues.

## Input and networking

Keyboard WASD, Shift, E, F, Escape; on Android, left virtual joystick, drag-look, separate USE/TORCH/RUN controls and sensitivity/quality settings. Direct native Godot ENet/UDP rooms host up to four players. Default UDP port 24711. Host validates handshake, protocol, passwords, range, state and movement; late joiners receive state. Host migration, a dedicated relay and guaranteed carrier-NAT traversal are not implemented. Optional UPnP may map a port, but manual port forwarding or the same LAN is often necessary. Story encounters are per-client. If the host leaves, clients return to the lobby.

## Assets and attribution

The supplied two branding images are `branding/game_icon.png` and `branding/team_logo.jpg`. Intro: **Made By Zorix GAme Team**. About Us: [zorix.it](https://zorix.it). About contains a credit section for the licensed third-party models and audio. The monster is a converted HorrorGameMaker/City Building Game Art CC0 FBX/texture asset with skin, skeleton and Walk2 import animation, stored byte-for-byte across `assets/entity.glb.part00`…`part11` to fit GitHub API upload limits. The resulting SHA-256 is `bf74395119a9c93aa13c46ec15d7facca2a314f9637e11de237a3bebb8ca9961`.

Other GLB furniture and captured surface textures are CC0 Poly Haven/ambientCG materials; Cesium Man is CC BY 4.0; recorded steps and ambience have documented licenses. Source URLs, pinned upstream hashes and license information are in [`backrooms_assets.json`](backrooms_assets.json) and [`ASSET_CREDITS.md`](ASSET_CREDITS.md); [`OFL.txt`](OFL.txt) covers the subset Chinese font. `fetch_backrooms_assets.py` downloads and verifies the upstream assets, then optimizes GLB texture sizes and subsets Noto Sans SC with all story copy.

## Build / checks

`../.github/workflows/faceless2-apk.yml` runs **Godot 4.7.2 headless** import/script checks, three-level gameplay/collision/resource suite, the one-shot story/monster/visibility/focus suite, and real ENet/UDP host/client/wrong-key/late-join/abrupt-disconnect processes before exporting Android 0.12.0, code 12, as `backrooms-v12-zorix.apk`. APK debug signing is not production signing. The CI must report a successful run and APK artifact at the intended commit before release. No graphical screenshots, Vulkan/Xvfb rendering, emulator, physical device install, or APK runtime tests are allowed; headless verification does not prove visual quality, mobile framerate, touch ergonomics, cross-network NAT or the absence of all bugs. Please refer to the run logs rather than treating the build as already verified.
