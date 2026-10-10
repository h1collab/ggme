# Backrooms / Night Relay (v0.12.0)

An atmospheric, narrative-led Backrooms horror game by **Zorix GAme Team**. You play a maintenance investigator from the Zorix anomalous-building unit, tracing a distress signal from a colleague inside an office tower that was demolished. Three connected spaces—offices, maintenance corridors and flooded pool halls—each contain a story briefing, repair objectives, cameras and a brief, locally staged creature sighting. The sighting emphasizes tension instead of combat.

The intro must read **Made By Zorix GAme Team**. The supplied icon and team logo are preserved in `faceless2/branding/`. [Team website](https://zorix.it).

## Playing

Open root `project.godot` in **Godot 4.7.2** (root `main.tscn` is the entry scene). Restore licensed external assets first for a local run:

```sh
python -m pip install Pillow==11.3.0 fonttools==4.61.1
python faceless2/fetch_backrooms_assets.py faceless2/assets/vendor
python faceless2/backrooms_audio.py audio
# The creature's original authored GLB is stored as exact, sha-verified segments in Git.
cat faceless2/assets/entity.glb.part[0-9][0-9] > faceless2/assets/entity.glb
sha256sum faceless2/assets/entity.glb
# expected bf74395119a9c93aa13c46ec15d7facca2a314f9637e11de237a3bebb8ca9961
godot --headless --path . --import
godot --path .
```

WASD/Shift/E/F/Escape on keyboard; joystick, right-side look and USE/TORCH/RUN on touch. Auto-look during creature sightings may be disabled in Settings and is interruptible by manual camera movement. Each floor requires fixing three relays, correctly identifying three camera faults, managing power, and reaching the elevator after the 02:00–06:00 shift.

## Multiplayer

Solo mode or **2–4 players** using native ENet/UDP P2P. Default UDP port **24711**, optional password and opt-in UPnP. The host owns shared progress and state; story sightings and camera focus are per-player and must not control remote players. No matchmaking, dedicated relay, universal NAT traversal or host migration is provided. Public-network sessions require a reachable host.

## Android and verification

[Android build workflow](.github/workflows/faceless2-apk.yml) builds debug-signed **`backrooms-v12-zorix.apk`**, version **0.12.0**, code **12**. It restores a pinned engine base, reconstructs and checks the authored CC0 creature GLB, downloads/checks pinned CC0/CC-BY external assets, generates sound, imports in Godot 4.7.2, and runs runtime, narrative and independent-process ENet/UDP headless checks before exporting the APK. Download from a **successful run on the development branch**, and verify that its commit matches the intended code. This repo intentionally never runs an Android emulator, installs an APK or captures graphical screenshots in CI; headless passes do not establish device FPS, rendering polish or touch usability. The APK is an unsigned-for-production debug build.

Asset provenance and redistribution licenses: [asset credits](faceless2/ASSET_CREDITS.md), [asset lockfile](faceless2/backrooms_assets.json), [SIL OFL](faceless2/OFL.txt). Creature: HorrorGameMaker/City Building Game Art (CC0); crew mesh: Cesium Man (CC BY 4.0). GLBs, captured surfaces and recorded audio are external licensed resources, not AI-generated meshes. `faceless2/assets/entity.glb.part*` concatenates to the unchanged converted GLB (original geometry, rig, animation and embedded 1024px textures); the segments are not independent models. Current production scope is a tested prototype, not a claim of AAA-level visuals.

See [full gameplay/network documentation](faceless2/README.md). Prior game source remains in `faceless2/legacy/`.
