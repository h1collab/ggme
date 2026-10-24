# Faceless 2 — The Other Shift (v0.16 / prototype)

A story-driven four-floor Backrooms horror exploration game by Zorix GAme Team. **Made By Zorix GAme Team** remains the opening line; the original branding and [official website](https://zorix.it) are unchanged.

A rescue call comes from the person standing behind you. Find real GLB almond-water bottles and access-key pieces, investigate three physical clues per floor, assemble the exit key at the desk and descend through the false rooms, flooded reflection pool and the zero shaft. Story scares happen in the **3D world**, not merely text: lights cut out, positional breathing and footsteps come from the wrong direction, and a skin-animated face appears in the darkness. One 0.65 s opening camera glance is local-only and can be disabled or interrupted manually. There are four floors and two outcomes.

## Rooms — no IP entry

Players open **房间合作** → create or join. Hosts choose **public** or **private** and an exact **2, 3 or 4 player** cap. Each room has an 8-character code; public rooms appear in a list, private rooms do not. Same-Wi-Fi discovery uses UDP announcements without an external account. To discover rooms **across networks**, deploy the included [JavaScript room directory](matchmaking/README.md) with HTTPS and set its URL in the lobby. Its JS service creates/lists/resolves room codes but does not relay gameplay: Godot ENet/UDP is still direct peer-to-peer, so hosts need a reachable UDP endpoint (UPnP or router forwarding). No fabricated NAT traversal or guarantee is claimed.

## Build and QA

Godot 4.7.2; root `project.godot` / `main.tscn`. Running `godot --headless` for all automated game tests is mandatory per [AGENTS.md](AGENTS.md); test with real Godot ENet processes, not mocks. JS directory tests: `node --test matchmaking/server.test.mjs`. APK is an export deliverable, not a runtime test. The [GitHub workflow](.github/workflows/faceless2-apk.yml) imports GLBs, generates Mandarin neural Kokoro speech **offline at build time** (neither system TTS nor fal.ai), runs headless tests, and exports `faceless2-v016-zorix.apk` only after they pass. Performance and visual quality on Android hardware remain untested in CI.

Third-party licenses: [credits](faceless2/ASSET_CREDITS.md), including Kenney Food Kit soda bottle and Mini Dungeon key (CC0), Huuxloc architecture (CC BY 4.0), Cesium Man (CC BY 4.0), original HorrorGameMaker monster (CC0), ambientCG/Poly Haven textures (CC0), and Kokoro neural voice (Apache 2.0). Visible objects are licensed GLB meshes; invisible low-cost collision proxy shapes are kept for physics.
