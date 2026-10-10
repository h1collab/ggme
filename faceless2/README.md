# Faceless 2 v0.16 — The Other Shift

**Premise:** During a rescue call, the investigator hears Lin Lan pleading from a dead phone while Lin Lan appears behind them. A short local-only opening face-in-the-dark event, mechanical silence, inverted footsteps, wet footprints and animated monster sightings establish danger through the playable space. No mandatory CCTV/power-shift or combat loop.

**Loop:** Pick up a real GLB almond-water bottle and access-key piece, investigate three distinct GLB-backed clues, physically reassemble the key at the investigation desk, then board the animated lift. Four connected thematic chapters (lost entrance, silent dormitory, premature water reflection, zero shaft) end in a host-authoritative send/seal choice. Scripted event gaze is short, optional and manually interruptible. Voice cues are pre-generated Mandarin OGG with Kokoro rather than Android TTS.

**Networking:** 1-player solo or create a co-op room of **2, 3 or 4 maximum participants**, public/private. Public rooms appear in a browsable list; private rooms require an 8-character code. Clients never type IP addresses. The JavaScript directory under `matchmaking/` must be **deployed** over HTTPS for discovery across networks; automatic LAN rooms use UDP broadcasts. Peer gameplay uses Godot ENet/UDP, one authoritative host. Session codes and lists are not NAT traversal; a reachable UDP host is necessary. No relay/host migration. Sudden disconnect clears a slot and GLB avatar. Events only steer local cameras.

**Visual/performance:** Licensed GLB architecture and props; skeletal/skin animation for monster, hands and visible feet. Shallow reactive water on every level, limited steps/particles and mobile resolution scaling. These are optimizations, not proof of real phone FPS or commercial AAA fidelity.

Automated gameplay QA is **Godot `--headless` exclusively** and the separate Node.js service is tested with Node's built-in test runner. Android APK is exported, not installed or run in CI. See [the root README](../README.md), [credits](ASSET_CREDITS.md), and [build workflow](../.github/workflows/faceless2-apk.yml).
