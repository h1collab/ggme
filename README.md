# Faceless 2 — The Signal Below

Atmospheric first-person Backrooms-inspired horror by **Zorix GAme Team**. This is **Faceless 2**, not an FNAF-style monitoring/night-shift game. The original logo, icon, `Made By Zorix GAme Team` opening and https://zorix.it About link are retained.

## Experience

Explore three linked spaces (disappeared offices, service depths, still water) and recover three audio memories in each level to trace a lost partner. There are no timed power-survival rounds, mandatory CCTV flicker reports, shooter mechanics, or hostile chases. The monster uses a licensed externally authored skinned GLB with `Walk2` animation: spatially recorded footsteps and breath lead short, rare local sightings where a face peeks from darkness, hesitates and retreats. Scripted camera assist is **off by default**, optional and interruptible.

The architecture uses Huuxloc's genuine CC BY 4.0 BackRooms GLB walls, trim, carpet and ceiling mesh components as instanced modules, with photography-based CC0 materials and separate simplified colliders for performance. Poly Haven CC0 furniture GLBs and Cesium Man CC BY 4.0 coop player remain. See [credits](faceless2/ASSET_CREDITS.md) and [font license](faceless2/OFL.txt). No AI-generated meshes were added.

## Build and QA

Use Godot 4.7.2. Main scene is `main.tscn` (the Android Actions workflow assembles the same scripts and licensed assets in `app/`). The [Android workflow](.github/workflows/faceless2-apk.yml) imports with Godot, runs three-layer gameplay/story tests and real independent headless ENet/UDP host, clients and disconnect checks, then exports the `faceless2-v014-zorix.apk` Android **debug** build (version 0.14.0/code 14). No emulator, APK installation, image capture or graphical tests are used.

Use WASD + mouse, Shift to run, E to collect/interact, F flashlight or touch joystick/look/buttons. Render-quality presets favor mobile stability; dynamic scaling is bounded. The original artworks are in `faceless2/branding`.

## Direct P2P

ENet UDP default port 24711, protocol 14, up to four, host owns shared clues/stage. Internet hosting needs a reachable UDP endpoint and may need manual port forwarding/optional UPnP; no relay or universal NAT traversal. Sightings stay local and cannot force remote camera orientation. See [implementation details](faceless2/README.md).

Android rendering quality, FPS, thermals and touch correctness require separate real-device validation; headless tests cannot demonstrate AAA quality or stutter-free behavior on every phone. PR updates do not merge to main without approval.

## v0.14: animation and recorded narration

The water halls now have on-foot contact ripples and subtle droplets with positional splash Foley. Lift rides physically animate sliding doors and a 6.2-second boarding/descending sequence before stage transfer; lift state is host-authoritative, but camera movement is local to those boarding. The first-person arms are the animated, licensed Cesium Man rig with leg/torso triangles removed (derived GLB; see `faceless2/create_viewmodel.py`). This does not fabricate limbs with primitives.

Chinese dialogue is synthesized **at build time** using the Apache-2.0-licensed **Kokoro-82M-v1.1-zh** neural model; the 15 generated OGG files are packaged, the model is not. No device/system TTS, no fal.ai. Players can toggle or replay generated audio from settings/HUD, and keep subtitles even with speech disabled. `faceless2/generate_sound.py` independently produces the short splash/lift Foley. Credits: [full licensing](faceless2/ASSET_CREDITS.md).

The mobile renderer intentionally uses a bounded shader/particle/lighting budget and limits dynamic resolution. Neither this CI nor Godot headless mode proves a commercial AAA visual result, stable physical-device FPS, touch correctness or thermal behavior.
