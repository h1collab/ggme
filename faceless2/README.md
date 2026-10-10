# Faceless 2 v0.14 — Exploration horror (Android)

Three contiguous floors use photographic CC0 materials and physically authored **Huuxloc BackRooms GLB** architectural meshes, with cheap separate collision shapes. Third-party credits and redistribution licenses: [ASSET_CREDITS.md](ASSET_CREDITS.md). Avoids generative 3D models.

Find three lost-partner recordings per floor and use the lift; the authoritatively shared recordings allow 1–4 ENet/UDP players to cooperate. No CCTV management, power countdown, shooter loop, or constant chase. Local skinned HorrorGameMaker/City Building Game Art creature occasionally appears from the corner after spatial footsteps, stops its walk animation while peeking, then hides; an optional manual-interruptible camera focus is disabled by default.

Control: WASD/mouse or touch joystick/look, Shift/RUN, E/USE, F/LIGHT, pause. Three mobile render quality tiers use 58%, 74%, 91% 3D scaling; bounded nearest-light shadow budget and reduced MSAA keep GPU use in check. Debug APK exports through `.github/workflows/faceless2-apk.yml` for version 0.14.0/code 14. Game tests run ONLY with `godot --headless`, including independent real UDP processes. No Android APK installation, graphics capture or emulators; visual polish/performance cannot be validated headlessly.

Direct UDP port 24711, protocol 14, optional UPnP/room key, no relay. The host controls clues and level transitions and validates proximity; clients never receive a camera override from the host. The original branding and `Made By Zorix GAme Team`, official https://zorix.it, are unchanged.

## Neural-generated Mandarin and cinematic gameplay (v0.14)

`generate_voice.py` generates 15 compressed Chinese story clips using Kokoro-82M-v1.1-zh on CI, with Apache 2.0 attribution. Not a system TTS API, and not fal.ai. It runs off-device and only ships OGG audio; generated audio playback has no inference latency. `generate_sound.py` builds three Foley WAVs: moving water footfalls, elevator door, and descending mechanism.

`create_viewmodel.py` keeps authentic skinned Cesium Man arm triangles while preserving its source animation. The six-second elevator is explicitly a deterministic state machine replicated by host epoch and elapsed progress; remote cameras remain local. Shallow water disturbances use an eight-event shader uniform buffer and a single seven-particle emitter. Godot headless cinematic checks verify wave triggers, bounded emissions, authored animation, narration resource availability, physical timing and camera release. Actual Android rendering and FPS remain unverified.
