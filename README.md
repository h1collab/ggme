# Backrooms / Night Relay

A monster-free, atmospheric Backrooms game by **Zorix GAme Team**, with three explorable layers and up to four-player direct P2P cooperation.

Observe actual live surveillance feeds, identify fluorescent circuit faults, repair three nodes, manage reserve power and physical isolation shutters, and complete each 02:00–06:00 shift to reach the next layer. Yellow-wall offices, maintenance corridors and vaulted pool rooms provide different materials and lighting. There are no hostile creatures, weapons or jump scares in this version.

## Run the current game

Use Godot **4.7.2**. The repository's root `project.godot` opens the current Backrooms main scene. Assets are procedural and the supplied branding is included; no Sketchfab account is required.

```sh
python faceless2/backrooms_audio.py audio
godot --headless --path . --import
godot --path .
```

Keyboard: WASD, Shift, E, F, Escape. Android: left joystick, right-side look, independent USE/TORCH/RUN touch controls. Quality and sensitivity settings are saved locally.

## Android APK

The [Backrooms build workflow](.github/workflows/faceless2-apk.yml) runs Godot **headless-only** gameplay, collision and real ENet/UDP cooperation tests, then exports `backrooms-v11-zorix.apk` (0.11.0 / code 11). APKs are built for delivery, never installed or run by the test pipeline. Graphical capture and emulator tests are disabled at the user's request. Download the APK artifact from the latest successful run on the development branch.

The root Android export preset selects only the new main scene, its dependencies, supplied branding and generated audio. The packaged workflow also supplies a PNG team boot splash. APKs are debug-signed test builds; production signing and physical-device performance validation remain release work.

## Cooperative play

Host a room and share your IP and UDP port (default **24711**), or join a host address. Same-network hosting works directly; Internet play needs a reachable public endpoint, optional UPnP mapping or manual port forwarding. There is no external matchmaking/relay service or guaranteed traversal of carrier NAT. The host stays online and owns shared progress.

See [game rules, networking details, testing and limitations](faceless2/README.md). [Official website](https://zorix.it).

Previous game source is preserved in `faceless2/legacy/` and ignored by Godot. The historical School Brawl workflow runs only on its historical branch or manual dispatch.
