# Faceless 2 v0.15 — The Signal Below / The Return

An exploratory, story-forward Backrooms horror game (Godot 4.7.2 / Android debug build). **Not** a FNAF-style shift, CCTV or resource-management game; no guns or shooting.

## Narrative progression

**Prologue — The demolished entrance:** a Zorix investigator follows missing partner Lin Lan to an office demolished five years earlier. Evidence: original demolition warrant, backwards wet footprints, night dispatch sheet bearing the player's prior signature.

**Chapter 1 — A third crew member:** infrastructure maps show a nonexistent basement, the powered-down machinery still breathes and an elevator shows a person wearing a colleague's clothes. Evidence: pipe schematic, respiration test, crew roster.

**Final chapter — Water remembers names:** Lin Lan's identity card is dated tomorrow, recordings refer to a seventh expedition, and the origin of the signal is revealed. Evidence: submerged badge, shaft maintenance log, original radio call. The final lift offers **SEND THE EVIDENCE** or **SEAL THE SIGNAL** with two authored epilogues. The evidence journal is accessible anytime, and a midway radio event changes the interpretation of each chapter.

Brief shadow silhouettes and spatialized footsteps can trigger at scripted locations, but no hostile combat, camera hijack or long pursuit. Auto-look defaults to off and can be overridden manually. In multiplayer, scripted camera controls affect only the local player.

## Art pipeline

- Visible architecture, floor, puddles, wall trim, doors, light housings and detail panels reuse imported **Huuxloc BackRooms** GLB mesh components (CC BY 4.0). GLB source is pinned and Draco-decoded at build time. Performance-friendly collision boxes have no visible mesh.
- CC0 **Poly Haven** GLB furniture provides varied physical story evidence and background props. No engine-generated BoxMesh, SphereMesh, ArrayMesh or CylinderMesh is used for *visible world geometry*.
- Monster mesh, animation and texture come from HorrorGameMaker / City Building Game Art under CC0; the original `Walk2` animation drives approaches and retreats.
- **Cesium Man** is the source for the first-person forearms, legs and shoes, extracted from the source GLB by skinning weights while preserving authored rig and walk animation. Arms respond to movement and idle breathing; look down to see the legs. We provide CC BY 4.0 credit.
- Standing water appears in **four zones per floor**, each with irregular softened shores, color/specular/Fresnel response and at most eight active ring impulses. A single reusable, 7-droplet emitter uses GLB support geometry. This avoids expensive render-to-texture reflections and procedural meshing during play.

See `ASSET_CREDITS.md` and `OFL.txt` for licenses and modifications. Derivative GLBs are *not* AI generated.

## Controls

Keyboard: WASD move, Shift sprint, E investigate, J evidence journal, F flashlight, Escape pause. Android: left virtual joystick, right swipe to look, RUN / 调查 / 手电 / 日志 buttons. Under Settings, choose rendering scale, sensitivity, generated narration and opt-in scripted camera focus.

## Sound and TTS

Build-time `generate_voice.py` creates **19 Mandarin neural OGG clips** from Kokoro-82M-v1.1-zh under Apache 2.0. No on-device speech engine, system TTS or fal.ai. Recorded CC0 3D ambience plus deterministic splash and lift foley are played with capped concurrency. No internet connection is required for playback.

## Direct multiplayer

ENet/UDP, 1–4 players, protocol **15**, room key + compatibility handshake, distance validation, host-owned evidence/lift/ending state, late join, and 15s killed-client seat cleanup. Direct public-IP/UPnP/port forwarding may be needed across networks; no relay or host migration.

## CI and scope

`.github/workflows/faceless2-apk.yml` restores pinned authored assets, builds the skinned limb derivatives, downloads neural TTS *only during CI*, checks asset inventory/geometry restrictions, then imports and tests with `godot --headless`. Gameplay, story, water/limb/lift and independent ENet/UDP scenarios gate APK export. Artifact: `faceless2-v015-zorix.apk`, 0.15.0 / code 15, debug-signed. The APK is not installed or run as a test. No graphic capture, emulator, physical device, frame-rate, thermal or smartphone touch performance test is claimed.
