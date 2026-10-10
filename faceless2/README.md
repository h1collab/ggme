# Faceless 2 v0.13 — Exploration horror (Android)

Three contiguous floors use photographic CC0 materials and physically authored **Huuxloc BackRooms GLB** architectural meshes, with cheap separate collision shapes. Third-party credits and redistribution licenses: [ASSET_CREDITS.md](ASSET_CREDITS.md). Avoids generative 3D models.

Find three lost-partner recordings per floor and use the lift; the authoritatively shared recordings allow 1–4 ENet/UDP players to cooperate. No CCTV management, power countdown, shooter loop, or constant chase. Local skinned HorrorGameMaker/City Building Game Art creature occasionally appears from the corner after spatial footsteps, stops its walk animation while peeking, then hides; an optional manual-interruptible camera focus is disabled by default.

Control: WASD/mouse or touch joystick/look, Shift/RUN, E/USE, F/LIGHT, pause. Three mobile render quality tiers use 58%, 74%, 91% 3D scaling; bounded nearest-light shadow budget and reduced MSAA keep GPU use in check. Debug APK exports through `.github/workflows/faceless2-apk.yml` for version 0.13.0/code 13. Game tests run ONLY with `godot --headless`, including independent real UDP processes. No Android APK installation, graphics capture or emulators; visual polish/performance cannot be validated headlessly.

Direct UDP port 24711, protocol 13, optional UPnP/room key, no relay. The host controls clues and level transitions and validates proximity; clients never receive a camera override from the host. The original branding and `Made By Zorix GAme Team`, official https://zorix.it, are unchanged.
