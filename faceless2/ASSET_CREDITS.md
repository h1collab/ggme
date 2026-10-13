# Faceless 2 v0.13 third-party asset credits

Character, creature and architectural meshes were created by their credited artists, not by generative AI. Godot instantiates/scales the licensed GLB meshes; lightweight box colliders are gameplay proxies, not visual replacements.

## Architectural GLB: Huuxloc — BackRooms (CC BY 4.0)

Original artist **Huuxloc** (`rjh41`) released the authored BackRooms scene under Creative Commons Attribution 4.0 International: https://sketchfab.com/3d-models/backrooms-1da6a7f2e0294ba9a4123f61244811a8 . Redistributable license: https://creativecommons.org/licenses/by/4.0/ .

Source model file `src/Models/Backroom.glb`, preserved from https://github.com/Menkoi/Backrooms/blob/0a73d6b6fa9fd01beccfa261edd7d4ae3301fde7/src/Models/Backroom.glb (Git blob `f7c83503ca46b6f9d6922337f3acc2dcef5ba76e`). GitHub adaptation by **Menkoi**, whom we also credit for making the compact glTF source accessible. Faceless 2 instantiates and scales its actual authored wall, trim, tiled ceiling and carpet geometry into gameplay modules, re-materializing surfaces with CC0 photo textures. Geometry was not synthesized from AI. Physics uses separate low-cost collision proxies. This is a modified modular use of the original model, not an unmodified scene.

## HorrorGameMaker entity

Author: City Building Game Art / HorrorGameMaker.com. Source: https://opengameart.org/content/3d-horror-game-monster . License: CC0-1.0 (https://creativecommons.org/publicdomain/zero/1.0/). Original Walk.fbx and authored PBR textures from Poses.zip were converted to embedded GLB using Godot; malformed embedded texture references were replaced by the separately supplied original albedo and normal textures. Texture resolution is reduced to 1024 for mobile, preserving the mesh, skeleton, skin and walk animation. No creature geometry was generated.

GLB SHA-256: bf74395119a9c93aa13c46ec15d7facca2a314f9637e11de237a3bebb8ca9961

## Vendor files

| File | Author/source | License | Original page |
| --- | --- | --- | --- |
| carpet.jpg | ambientCG | CC0-1.0 | https://ambientcg.com/view?id=Carpet009 |
| ceiling.jpg | ambientCG | CC0-1.0 | https://ambientcg.com/view?id=OfficeCeiling005 |
| wallpaper.jpg | ambientCG | CC0-1.0 | https://ambientcg.com/view?id=Wallpaper001A |
| poolfloor.jpg | ambientCG | CC0-1.0 | https://ambientcg.com/view?id=Tiles132A |
| pooltile.jpg | ambientCG | CC0-1.0 | https://ambientcg.com/view?id=Tiles107 |
| schoolchair.glb | Poly Haven / see source page | CC0-1.0 | https://polyhaven.com/a/schoolchair_01 |
| schooldesk.glb | Poly Haven / see source page | CC0-1.0 | https://polyhaven.com/a/schooldesk_01 |
| cabinet.glb | Poly Haven / see source page | CC0-1.0 | https://polyhaven.com/a/drawer_cabinet |
| shelf.glb | Poly Haven / see source page | CC0-1.0 | https://polyhaven.com/a/steel_frame_shelves_03 |
| barrel.glb | Poly Haven / see source page | CC0-1.0 | https://polyhaven.com/a/barrel_01 |
| concrete.jpg | Poly Haven | CC0-1.0 | https://polyhaven.com/a/concrete_floor |
| concrete_normal.jpg | Poly Haven | CC0-1.0 | https://polyhaven.com/a/concrete_floor |
| concrete_rough.jpg | Poly Haven | CC0-1.0 | https://polyhaven.com/a/concrete_floor |
| breathing.mp3 | Freesound contributor / source ID | CC0-1.0 | https://freesound.org/s/574208/ |
| hum.mp3 | Freesound contributor / source ID | CC0-1.0 | https://freesound.org/s/777053/ |
| water.mp3 | Freesound contributor / source ID | CC0-1.0 | https://freesound.org/s/861351/ |
| monster_step.ogg | GboxMikeFozzy | CC0-1.0 | https://opengameart.org/content/footsteps-0 |
| crew.glb | Cesium (2017) | CC-BY-4.0 | https://github.com/KhronosGroup/glTF-Sample-Assets/tree/edc7c9e67c639d230715049ee31f9a96a6babbbe/Models/CesiumMan |

Cesium Man © 2017 Cesium, licensed CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/). The Cesium logo belongs to Cesium; inclusion of the model does not imply sponsorship. Embedded textures may be resized; rig, mesh and animation data are preserved.

AmbientCG textures and Freesound files are redistributed from the pinned Liminal mirror, whose per-file provenance is https://github.com/yerdaulet-damir/liminal/blob/ff9ee5b57e2531b4f8841d6e7564283f943f6d34/assets-manifest.json . Poly Haven GLBs come from the pinned CC0 catalog mirror; source pages remain linked above.

Chinese font: Noto Sans SC, Google/Noto contributors, SIL OFL 1.1. Subset and renamed Zorix Story Sans. Full font license is supplied in OFL.txt. See https://github.com/notofonts/noto-cjk .

Original machinery relay WAV and fallback audio were created for Night Relay. Branding was supplied by the project owner.

## Faceless 2 v0.14 authored interactions and synthesized dialogue

The first-person hand viewmodel `first_person_arms.glb` is a deterministic **subset of the original Cesium Man GLB**, using only skin-weighted arm triangles and preserving the rig, animations, UVs and skin. This is a modification of the CC BY 4.0 model, **not** a newly created AI mesh; see `create_viewmodel.py`. Creative credit remains **Cesium (2017)**.

Narration is **offline neural text-to-speech generated by Kokoro-82M-v1.1-zh**, by hexgrad, Apache License 2.0: https://huggingface.co/hexgrad/Kokoro-82M-v1.1-zh . The original model's README describes the Chinese dataset as donated permissively by LongMaoData. The engine/model is downloaded on CI for synthesis only, not included in the APK. `generate_voice.py` renders and compresses pre-generated Mandarin clips; the game **does not use the Android system TTS service** and **does not invoke fal.ai**. The license is supplied as `KOKORO_APACHE_2.txt` in the APK. Generated speech is synthetic and not a real recording of a named individual.

`generate_sound.py` creates original, deterministic low-cost splash, elevator door and motor Foley as offline PCM WAV files. Gameplay uses positional recorded audio from the vendor list for room-tone, monster footsteps and breath, and these separately generated Foley assets for reactive interaction.

Water is a custom PBR-inspired Fresnel/normal shader with an eight-impulse ring buffer and a capped seven-particle splash emitter; it uses no GPU-heavy screen-space reflection. Elevator motion is locally animated in stages with door panels and audible mechanical transitions; no remote player camera is driven by RPC.

## v0.15 flooding, GLB construction, legs and interactive story

All newly visible 3D architecture, lift panels, consoles, puddle planes, evidence indicators and droplet meshes **reuse existing Huuxloc-authored BackRooms GLB mesh data** (artist Huuxloc, CC BY 4.0) via import and transforms, *not procedural primitive render meshes*. Additional investigation objects use Poly Haven CC0 furniture GLBs. Invisible `BoxShape3D` and `CapsuleShape3D` objects are collision proxies and are not rendered. The water surface shader is code; it changes the material appearance/edge opacity of Huuxloc's authored plane mesh and emits a bounded animated disturbance. This is a modified use of the original asset under attribution, not a claim that every environmental prop was modelled specifically for Faceless 2.

`first_person_legs.glb` derives **904 skinned leg/foot triangles** from the original Cesium Man model (© 2017 Cesium, CC BY 4.0). `first_person_arms.glb` retains 546 original skinned arm triangles. Both remain authored Cesium meshes with source bones, UVs and animation; no generated humanoid geometry. The extracted file remains licensed CC BY 4.0 and bears a source attribution in `asset.extras`.

The 19 synthetic Mandarin voice clips include revised investigation records, three interlude transmissions and an alternate ending, generated **offline** with Kokoro, Apache 2.0, never system TTS or fal.ai. Character identities and supernatural fiction are original narrative content and do not impersonate a real person's voice.

### New v0.16 real pickup GLBs (no AI-generated geometry)

- **Almond water bottle:** Kenney / Food Kit, `soda-bottle.glb` (embedded-texture glTF converted by Hidencod/tge-assets); **CC0 1.0**. Original author: [Kenney](https://kenney.nl/assets/food-kit). Reused as almond-water prop in Faceless 2 without altering its authored geometry. Pinned redistributed Git blob `6dea17f5ccfb18356e3643ca6cb3b371b0dd2144` ([source](https://github.com/Hidencod/tge-assets/blob/main/packs/food-kit/soda-bottle.glb)).
- **Elevator key:** Kenney / Mini Dungeon Kit, `key.glb`; **CC0 1.0**. Original author: [Kenney](https://kenney.nl). Converted to embedded-texture GLB by Hidencod/tge-assets, unchanged authored geometry. Pinned Git blob `640ae2dfbd57a19d1b8c9e122f6d5b9c30f8e5bc` ([source](https://github.com/Hidencod/tge-assets/blob/main/packs/mini-dungeon/key.glb)).
- CC0 source verification: [Kenney asset repository license](https://github.com/Hidencod/tge-assets/blob/main/LICENSE). Short script-based material hints, signal markers, narration and invisible collision proxies are not replacement models.

## v0.18 / The Other Shift phone-call prologue

- **iPhone 17 Pro**: original creator **Ranguel**, [original Sketchfab model](https://sketchfab.com/3d-models/iphone-17-pro-4541aa8a28324b33a2baaf81d263aaec), **CC BY 4.0**, non-official fan-made visualization. The same original GLB is redistributed (with the creator and license credited) in Quentin PLA's [phone-mockup-studio](https://github.com/quentin-pla/phone-mockup-studio/blob/9908f2c321787779b6e028cba1ab67cd29a6a6dd/CREDITS.md), under `source/iphone_17_pro.glb`. The official Sketchfab API download with an existing credential is attempted first; when unavailable, the public CC BY 4.0 copy is downloaded from commit `9908f2c321787779b6e028cba1ab67cd29a6a6dd`, with pinned Git object SHA-1 `31d6a04caabcca2fb717738079ca66da59347647` and length 24,368,404 bytes. Both routes include the real, externally authored model; a hand-built approximation is not substituted. Apple is a trademark of Apple Inc. This is not an official Apple asset or endorsement.
- **Room**: Existing Huuxloc *BackRooms* (CC BY 4.0) architecture and Poly Haven (CC0) GLB schooldesk/furniture are reused for the opening; a separate Sketchfab bedroom is not included.
- **Audio**: ringtone, disconnection cue, static and fall are reproducible build-generated PCM from `faceless2/generate_sound.py`; no Android or runtime TTS. The Freesound CC0 *Static Voice* candidate was researched but is not included or misattributed.
- **Languages**: English is the initial UI and subtitle language; Simplified Chinese can be selected and saved. Existing Kokoro speech remains pre-generated Mandarin and is only enabled in Chinese mode, not falsely presented as English dub.

## v0.20 / BLACK-SITE WAKEUP (cinematic scene)

- **Kenney Space Station Kit**, modular authored GLB models (wall, pillar, wall window, door, floor panel, pipe, computer screen, container, structural panel), by **Kenney**, **CC0 1.0**, source https://kenney.nl/assets/space-station-kit . Repacked as separate real GLBs in https://github.com/Papyszoo/CC0-Public-Domain-Models/tree/77343cac874f06b73d16ad0063339df7c9ca254c/packs/kenney-space-station-kit . Build process verifies Git blob hashes and model sizes in `fetch_wakeup_assets.py`. Facility only uses authored models, not generated geometry. This is an **Area 51-inspired fictional research facility**, not a real reconstruction or endorsement.
- **Phone caller surface**: the body is still Ranguel's independently licensed CC BY 4.0 iPhone 17 Pro GLB (see v0.18 credits); the lit screen texture, typography and incoming-call state are authored entirely in Godot at runtime and do not claim to be copied from Apple's iOS design. Default English and optional Simplified Chinese.
- **Wake effect**: local low-cost vignette/opacity recovery, 3D floor-level camera lift and caption typewriter `Where am I?` use procedural timing and existing bundled font. No new model copyrights or runtime network downloads are required.

## v0.22 / Skeletal Smiler scare and controllable first-person hands

This release **requires two original external Sketchfab GLBs**, downloaded using the official authenticated Sketchfab Download API at build time; no locally created character/primitive fallback is allowed. Build must fail if either model cannot legally be downloaded or verified as CC BY 4.0. Source manifests with exact generated GLB SHA-256 are packaged next to the models.

- **Smiler**, *Accurate Smiler Backrooms Blender 3.22*, creator **Speed12**, original Sketchfab: https://sketchfab.com/3d-models/accurate-smiler-backrooms-blender-322-902975161a7047baa5cda8fb7b5a292e — claimed source CC BY 4.0, to be verified against the live Sketchfab API at build time. Used as an authentic third-party 3D entity watching and rushing in the darkness, no generated geometry replacement.
- **First-person arms**, *First Person arms*, creator **DJMaesen**, original Sketchfab: https://sketchfab.com/3d-models/first-person-arms-e3c42c05b22944e5839deb8e003f0987 — claimed source CC BY 4.0, to be verified against live Sketchfab API at build time. Original skin and meshes used in live player view and awakening.
- **Doors**, Kenney *Space Station Kit* CC0 GLBs; same source/repacked Git pin and attribution as the v0.20 facility set. Door collisions and floor collisions are invisible simple collision shapes only.
- Sound and light: source-authored GLB model is retained. Prologue uses already packaged spatial shutter audio; the wake-up shader is dismissed when player control begins so hands and nearby details are sharp.

Do not redistribute either of the above Sketchfab downloads if their live license or API download permission has changed; the build importer explicitly enforces this.

## v0.26 — Liminal observation wing and circuit props (Kenney CC0)

The observation wing is an original **layout and gameplay arrangement made from licensed third-party Kenney geometry**, not an AI or procedural primitive model. The `faceless2/bake_laboratory_glb.py` CI step packs verified Kenney Space Station Kit source GLB mesh vertices into distinct mobile-friendly building sectors: `facility_corridor_cc0.glb` (shared corridor), `laboratory_shell_cc0.glb` (sealed laboratory) and `observation_wing_cc0.glb` (lazily loaded observation room). Original artist: **Kenney**, source https://kenney.nl/assets/space-station-kit ; **CC0 1.0**, freely redistributable and commercially reusable (https://creativecommons.org/publicdomain/zero/1.0/). Conversion, repacking, merging and scene layout are modifications. The build appends the **actual SHA-256** of all three output GLBs to the packaged `ASSET_CREDITS.md`; its `qa/laboratory-shell.json` contains byte sizes, source module counts and hashes. Never substitute a different model without its own verified license.

New visible external props `wakeup_wall_switch.glb` and `wakeup_chair.glb` are original **Kenney Space Station Kit CC0** models, downloaded by `fetch_wakeup_assets.py` from the pinned `Papyszoo/CC0-Public-Domain-Models` mirror at commit `77343cac874f06b73d16ad0063339df7c9ca254c`. Upstream source-archive Git blob hashes: `afd544793eb363d788dc195c3af319d03384a2fc` (wall_switch, 10632 bytes) and `e10229e50bbb4a737656c27df65451fa7b0cfd82` (chair, 14392 bytes). Files are size- and Git-hash checked before rendering, as with the existing Kenney kit. They are animated transforms on real imported GLB meshes, not simple visible BoxMesh stand-ins.

## v0.30 visual-clipping QA / Level ! CC0 monster substitution

The white Cesium Man astronaut was a placeholder-like non-hostile witness used in new exploration sectors. It has been removed **from those additional-sector entity spawns** (the skinned Cesium first-person feet are still licensed separately). Passive distant sightings now use the **existing HorrorGameMaker/City Building Game Art CC0-1.0 authored animated monster GLB**, already credited above and verified against SHA-256 `bf74395119a9c93aa13c46ec15d7facca2a314f9637e11de237a3bebb8ca9961`. This is an original third-party model, **not** a self-created primitive or a replacement for the original Sketchfab Smiler; witness behavior remains non-hostile.

Level ! (route ID 132) uses the same actual imported licensed monster GLB for its passive events, plus original **Kenney Space Station Kit CC0** airlock/door/bulkhead/wall modules and **Poly Haven CC0** scanned industrial props. Existing authored Kenney wall geometry has been re-anchored to its base, and side-room walls/floors/collision extend to exactly the doorway opening. The original Sketchfab Smiler remains a CC BY 4.0 source-baked depth-tested Sprite3D in other levels; it appears only at an approached, physically unobstructed corridor end instead of being embedded in the side wall. No new external or unlicensed assets were added in this change.

## v0.30 GLB wall, bulkhead, elevator, and stair closure pass

All additional *visible* sealing panels, interactive metal door leaves, vestibule, end-caps, cabin shafts, stairs and exterior wall backing continue to use the **unmodified source triangles of Kenney Space Station Kit / CC0 1.0**; `wakeup_floor_panel.glb` (source Git blob `9390db0076481208a69600a9cf5bd9c1c21eee69`, 16,344 bytes) is only transformed/rotated and measured in `backrooms_assets.gd::licensed_panel()`, not replaced by visible BoxMesh, a generated/AI façade, or a copied commercial model. Source provenance, revision and exact file hashes are independently enforced by `fetch_wakeup_assets.py`, with license/source at https://kenney.nl/assets/space-station-kit and fixed source commit `77343cac874f06b73d16ad0063339df7c9ca254c`. Thin invisible `BoxShape3D` volumes remain legitimate collision proxies.

Building metal and wall backers use the **already credited Poly Haven CC0** downloaded diffuse + normal + roughness textures, fixed upstream hashes/size validation in `fetch_real_backrooms_assets.py`. Real GLB wall panels are sealed behind decorative slots and new elevator sliding leaves are opaque, so seeing between original wall details cannot expose an unbuilt black world. Large infill uses **metric triplanar PBR** to avoid stretched source UV and is limited to these infill meshes to conserve mobile GPU draw costs. No new external assets or changed commercial licenses are introduced. Android FPS and all collision angles still require physical device checks.

## Standalone FPS / original Kenney Blaster Kit GLBs (CC0)

Creator and publisher: **Kenney**. Original asset page: https://kenney.nl/assets/blaster-kit . Original asset-pack license: **CC0 1.0 Universal** (commercial reproduction, modification and redistribution allowed): https://creativecommons.org/publicdomain/zero/1.0/ . We continue to provide Kenney attribution as a best practice even where CC0 imposes no formal attribution requirement.

Our exact glTF-Binary versions are sourced from the public CC0 model mirror **Papyszoo/CC0-Public-Domain-Models**, fixed revision `77343cac874f06b73d16ad0063339df7c9ca254c`, under `packs/kenney-blaster-kit/models/` (not newly created approximations). Imported geometry remains the original authored GLB mesh triangles and embedded material textures; no visible BoxMesh or procedurally generated weapon substitutes. Files, byte sizes, Git blob checksums and **SHA-256** are enforced by `fetch_fps_assets.py` before Godot import:

| Package file | Original Kenney model | Length (bytes) | Upstream Git blob | GLB SHA-256 |
|---|---|---:|---|---|
| `fps_blaster_f.glb` | `blaster_f/blaster_f.glb` | 82,676 | `54c9c7988cec2294c9d8ef4b5cfcbf125a76f76e` | `e1fd9bb8839cc60d26bd12d5093cadccda22943b29db6c5846f8e9ec66309868` |
| `fps_target_large.glb` | `target_large/target_large.glb` | 17,792 | `c9dabfded68fd9693cad975bb5abc30af9503b4c` | `92cd7fb5faaaa0a118fccb9c374121fd56dd7f5bf16d9842c7114c243ae74be4` |
| `fps_clip_small.glb` | `clip_small/clip_small.glb` | 18,036 | `22d033e4c07177f09a951cf06e3cf926d19ecb87` | `cf282a14a7cbe5de85a5977a144240d4343faf4f70b37d24d53624f91a738740` |

The single FPS arena floor consists of transformed, licensed **Kenney Space Station Kit CC0 `wakeup_floor_panel.glb`** originals, plus previously credited Poly Haven CC0 concrete diffuse / normal / roughness textures. The source GLB is independently Git-object verified by `fetch_wakeup_assets.py`. Collision-only invisible `BoxShape3D` proxies delimit the playfield; gameplay hit-ray targets use invisible Godot collision shapes, not visible primitive mesh objects. Kenney Blaster Kit is a stylized sci-fi asset, **not** represented as a photogrammetric modern firearm or AAA-quality model. No generative model files or unknown commercial assets are introduced.

## FPS skinned replacement hands — WRAD ARMS (CC0)

**Author:** wriks / WRAD ARMS, original project https://github.com/wwwriks/wrad-arms ; **license:** CC0 1.0 (including commercial redistribution), https://github.com/wwwriks/wrad-arms/blob/f3987244176c33d2c20d4f9e139980af12684d87/LICENSE . Original fixed binary `arms.glb` (456328 bytes), revision `f3987244176c33d2c20d4f9e139980af12684d87`, Git blob `be023c46705bf8571e9ab97dbd3e71d2f18f8473`, SHA-256 `580efbb0852bf0b41f82dd3e17eafec86b3d2a48f4a7acaa7e64d60e850f565d`. `fetch_fps_assets.py` validates both object ID and SHA-256, source skeleton and skin before writing `fps_wrad_arms.glb`. Reposed at runtime using the original named finger, wrist, forearm and upper-arm bones for weapon grip. **The original CC0 meshes and skins remain untouched; this is a licensed pose modification, not a new AI mesh.** FPS mode hides the previous separately displayed Sketchfab hands to prevent double-arm overlap.

**Visual QA revision:** The initially imported WRAD GLB revealed overly long, disconnected elbows in actual Godot ADS/hip screenshots even though wrist IK numerical errors were small. `bake_fps_grip_hands.py` now retains only source-authored WRAD wrist, palm and finger triangles (expected approx. 856 of 1196 original triangles), keeping original skinned vertices, UVs, normals and material. Source `fps_wrad_arms.glb` retains upstream SHA-256 check and derived `fps_wrad_grip_hands.glb` is baked on the trusted CI runner for the FPS view only. Do not restore floating upper-arm geometry.
