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

**Historical visual QA revision (superseded by the current forearm subset below):** The initially imported WRAD GLB revealed overly long, disconnected elbows in actual Godot ADS/hip screenshots even though wrist IK numerical errors were small. That revision of `bake_fps_grip_hands.py` retained only source-authored WRAD wrist, palm and finger triangles (expected approx. 856 of 1196 original triangles), keeping original skinned vertices, UVs, normals and material. Source `fps_wrad_arms.glb` retains upstream SHA-256 check and derived `fps_wrad_grip_hands.glb` is baked on the trusted CI runner for the FPS view only. Do not restore floating upper-arm geometry.

## Publisher integrity diagnostics (2026-10-14)

Poly Haven downloads still require the exact size and MD5 from the publisher API.
A failed response is discarded and retried at most three times against the same
record; persistent mismatch fails the build. Public source URL, status, MIME type,
expected/actual size and MD5, and actual SHA-256 are recorded. No license, source
URL or accepted digest was replaced to work around the vintage_day_bed failure.

## WRAD grip alignment correction (2026-10-14)

Source remains wriks / WRAD ARMS CC0 at f3987244176c33d2c20d4f9e139980af12684d87,
SHA-256 580efbb0852bf0b41f82dd3e17eafec86b3d2a48f4a7acaa7e64d60e850f565d.
Each side now retains 589 original bicep/forearm/wrist/finger triangles (1178 of
1196 combined). Only existing original attribute rows are copied with a common
index remap; original UV, normals, materials, skeleton and inverse binds remain.
Runtime aligns authored wrist/socket frames to measured Kenney pistol-grip and
fore-end coordinates, with additional local-Z finger curls. Bone/socket and
CPU-skinned vertex distance checks replace the previous constant-zero error.
Gun orientation is corrected using original geometry. This is still a stylized
Kenney blaster, not a photorealistic modern pistol. Visual acceptance requires
inspection of the SHA-matched native Godot screenshots and movie.

The current subset keeps 589 original bicep/forearm/wrist/finger triangles per side
(1178/1196 combined), excluding only shoulder-end faces. Runtime rigid forearm
articulation places the original shoulder ends beyond the bottom of the view;
cutting at the elbow exposed visible open forearm ends and is not retained.
No triangles are added; the author, CC0 license, source SHA, bind data, normals and UVs remain unchanged.

## Functional original-geometry ADS optic

`fps_blaster_f_open_optic.glb` is a CC0 derivative of the unchanged verified
Kenney Blaster Kit `fps_blaster_f.glb` (source/mirror/revision and original
SHA-256 remain as recorded above). `bake_fps_optic.py` requires that exact
82,676-byte source and removes exactly 12 original opaque lens-cap faces
(192/204 original scope faces retained), preserving every original vertex
attribute, texture, material, gun-body and magazine index stream. No new
visible geometry is generated. The derivative SHA-256 is logged at build time;
the original firearm file is also packaged for provenance.

Open-optic derivative pinned SHA-256:
`6256615dc836e0d51a4a082c70892988608469b82f47c5937aec5099b584a2fb`.
This is the locally reproduced lawful derivative hash, never an accepted
replacement for the original publisher file's unchanged SHA-256.

## FPS recoil/material/lighting polish (2026-10-14)

Weapon PBR detail: Metal Plate 02 by Rob Tuytel, Poly Haven, CC0 1.0; official source https://polyhaven.com/a/metal_plate_02. Original 1K JPG diffuse/GL-normal/roughness/metallic maps are unmodified. `fetch_fps_surface.py` pins official URL, byte length, publisher MD5 and independently verified SHA-256; a publisher change fails instead of rewriting expected hashes. The original Kenney atlas defines material regions; local-space shader shading adds graphite/alloy finish and restrained scanned surface detail without replacing original gun geometry.

- diffuse: https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/metal_plate_02/metal_plate_02_diff_1k.jpg; 625917 bytes; MD5 531b7e067dc537e0b3c7962175e04ffd; SHA-256 6e80877d0e9d5973d96298c6091df7ace906b0a6760afc4f3592e4855f3f1d4c.
- normal: https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/metal_plate_02/metal_plate_02_nor_gl_1k.jpg; 183264 bytes; MD5 ce8198004fd9409f592a7f024be0c01e; SHA-256 58736fbb8aa4fc6690cf8152b174db65caf22a766375b625fb0087e1bc955bc7.
- rough: https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/metal_plate_02/metal_plate_02_rough_1k.jpg; 911772 bytes; MD5 1fa97d5031aa575656a316bfd404ca4d; SHA-256 73a6bd6393f6de7be42058584c2d382f2a3e9148ceabc2d02e748e2c860e74d1.
- metal: https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/metal_plate_02/metal_plate_02_metal_1k.jpg; 551170 bytes; MD5 6ecfe9cdb7e0147c3dd7b49776d4a7d6; SHA-256 fb1b120a2be5887dfeebed7a198a8151b292e963713d914b74ed7669434afb41.

Arena floor uses previously verified Poly Haven Large Grey Tiles CC0 diffuse/GL-normal/roughness on the original Kenney floor GLB, with world-metric projection. Hands retain the unchanged original WRAD albedo and skin; runtime material tint/roughness/specular settings control exposure. The local ground-shadow caster is original licensed crew.glb, rendered shadow-only. Its pose differs from the first-person arms, so the first-person rig receives direct sun/sky lighting independently of the body shadow. Sun/sky/reflections and short muzzle illumination are native lighting, not generated visible geometry. No external asset licensing or hash checks are removed.

## v0.32 two-map architecture and photographic sky

Cargo Courtyard and Maintenance Hangar are independent FPS layouts. Structures, floor/roof panels, pillars, containers, pipes and consoles reuse the already verified original Kenney Space Station Kit CC0 GLBs from `fetch_wakeup_assets.py`; scanned barrels, boxes and industrial wall lamps reuse original Poly Haven CC0 GLBs from `fetch_real_backrooms_assets.py`. Existing publisher hashes and source credits remain checked. Reorientation/scaling and runtime source-PBR material assignment are lawful modifications, not newly downloaded unverified geometry. Gameplay collision boxes are invisible.

Kloppenheim 06 Pure Sky — Greg Zaal (original) and Jarod Guest (pure sky edits), Poly Haven CC0-1.0, https://polyhaven.com/a/kloppenheim_06_puresky. Original unmodified 1K HDR: https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/1k/kloppenheim_06_puresky_1k.hdr . Publisher bytes **1173154**, MD5 `995d68b1656f26452572645c0ffe898b`, independently verified SHA-256 `206c67e3a1b992282821cf06662bdd69bbb4915c1c4444a66338a40d6a7d4e34`. `fetch_fps_surface.py` rejects changed metadata, URL, size, MD5 or SHA-256. No AI-generated texture or substituted gun/hand is introduced.

## Original four-corner FPS UI vectors

`faceless2/hud_icons/*.svg`: original project-native vector paths created for this change, dedicated CC0-1.0. These are generic weapon/ammunition/health/room/map/score/aim/reload/jump/run/pause symbols; no external SVG library, font icon or third-party game artwork is copied. Counts and combat feed come from actual host-authorized state; no unimplemented grenade count is fabricated.
- faceless2/hud_icons/aim.svg: SHA-256 `0ec4d4663ce8be0ceb66ce5c01dff9c54ceb72733560c18be6b215c84c3ba7d2`.
- faceless2/hud_icons/bullet.svg: SHA-256 `7c66735aed75f2bf87fb30b9118b9d9652264ca5d5c561bac55deecf5bb186a3`.
- faceless2/hud_icons/health.svg: SHA-256 `f920709e562f8ee897ba15404d993c9dff555d7f2876b1fb111599f05717941c`.
- faceless2/hud_icons/jump.svg: SHA-256 `d9c360e9d921788f5dfe016753c82d5c8394f1ed1f0a464f68dcb49659f90dfb`.
- faceless2/hud_icons/map.svg: SHA-256 `405b082e897be3c77db6f7e5b5638d89e2a0d3c0167d00d63f29fad5bfd7cd6d`.
- faceless2/hud_icons/pause.svg: SHA-256 `f21ee41b650df5deecd4eddb781b9092536eb36a513f6768f9234370106601ba`.
- faceless2/hud_icons/people.svg: SHA-256 `b63cbbbd53eff27744246414ab437d7cc8d4a3699e1b804a23e7080a723f4c7c`.
- faceless2/hud_icons/reload.svg: SHA-256 `3aff55a4821afed355baa4e0817deba351d2d2431b430d24e2b687c1a871d3d3`.
- faceless2/hud_icons/run.svg: SHA-256 `bed3f6458b0250c5a048b4f1ac40bf31b4a2bcecbf9b55cf17a77cd5dd2541d7`.
- faceless2/hud_icons/score.svg: SHA-256 `053eebf7a44fea1ccaccddf1ff901e66b6309fa2a8ac30080a410292633c403d`.
- faceless2/hud_icons/weapon.svg: SHA-256 `d35a2421ef02e1aa99ff6dd95e426b45c98939c042feefbfb3106940489f53f2`.


## v0.34 source-authored M4A1 reference rifle

- **M4A1 Assault Rifle**, nisu / 3DModelsCC0; **CC0 1.0**. Publisher's dated release and license: https://opengameart.org/content/m4a1-assault-rifle (24 April 2022). Its linked original 3dmodelscc0.com page is currently unavailable; use the publisher-hosted archive, not that domain. This is an authored 2022 FBX and texture release, not a model extracted from the screenshot or another game.
- Publisher ZIP: https://opengameart.org/sites/default/files/m4a1_0.zip ; SHA-256 `ed5779ec82718861964227e2aad2a900978ea087081154365d6d86246be62f0d`. Full six-file source byte lengths and SHA-256 values are pinned and verified in `fetch_fps_rifle.py`. Base color, normal, metallic and roughness are original supplied 2048px maps; height source is retained. No source texture is relabeled as another author's.
- `backrooms_bake_rifle.gd` uses **Godot 4.7.2 native ufbx + GLTFDocument** in headless mode to preserve the original meshes/UVs and embed original PBR maps into `fps_m4a1.glb`. Actual importer inventory: **9,258 triangles**, 13 source mesh parts, including Magazine, Charging_Handle, Trigger, Barrel and Stock. Conversion changes material channel bindings only; no generated visible gun geometry. Runtime animates original magazine/handle transforms.
- The existing Kenney original/optic GLBs, WRAD source and licensed skinned subsets remain preserved and verified. WRAD wrist/socket alignment is recalibrated to measured points on the M4A1's actual triangles; both hands remain source skinned GLBs. This does not imply the grasp is free of all intersections.
- `hud_icons/impact.svg` is original repository-authored 2D vector art for temporary surface marks. It is a small transparent Sprite3D decal, never a substitute for the gun, hands or architecture. Authored GLB panels/pillars form added range partitions; numbered Label3D signage is original text. No reference screenshot content is shipped as a game texture or model.

- Legacy huuxloc source is retained at SHA-256 `948d80d419152b82cdedd03ce92cace39fbcd69d6801330cd3021995456c984c`. `decode_backroom_glb.py` replaces a failing npm CLI with build-only **DracoPy 1.5.0**, an Apache-2.0 wrapper for Google's Draco (https://github.com/seung-lab/DracoPy). Strict source hash, 26 meshes, 3,912 triangles, attribute/index counts and finite values are verified. Original node/material/texture/UV/normal data remain; no geometry is synthesized. Decoded output SHA-256 `99d5f83a419919a51f5f692095dae0f80f432b0376a90c2d595e64a28ddca84c`.

- v0.34 native review exposed stock intersections; an intermediate 521-face elbow crop then exposed open forearm ends. The final source subset preserves **589 original bicep/forearm/wrist/palm/finger triangles per side** (1,178/1,196 total). Rigid forearm articulation and opposite wrist articulation preserve the calibrated grasp and original segment length, moving the original shoulder cut outside the view. Counts remain exact and the untouched source hash is unchanged. No face/UV/normal/bind data is synthesized or relabeled. Native review remains required.


## v0.35 explicitly modified WRAD CC0 surface derivative

The untouched wriks WRAD ARMS source remains pinned to commit
`f3987244176c33d2c20d4f9e139980af12684d87`, SHA-256
`580efbb0852bf0b41f82dd3e17eafec86b3d2a48f4a7acaa7e64d60e850f565d`.
The historical v0.34 589-face subsets described above remain the verified
intermediate input; the shipped v0.35 left/right arms are **modified derivatives**.
`refine_fps_arms.py` applies two deterministic offline Loop subdivision passes,
producing 9,424 triangles / 5,222 render vertices per side. Positions and skin
weights are interpolated; original UV chart boundaries are preserved, UVs
interpolated and smooth normals recomputed. Four strongest skin weights are
renormalized (maximum discarded influence 0.088481). The original skeleton,
inverse bind bytes, materials and embedded images are unchanged. This is not an
unchanged-original-mesh claim. Source and CC0 attribution are retained.

Derived right GLB SHA-256:
`c5976b1afadea228f00835a7a686ff9efe1a797b5497955a3ca8675af91f88be`.
Derived left GLB SHA-256:
`64329bed354ad77f3b0766da7ed5ada093d2c982d02b0860c22e4744dc8ffc9c`.
`test_refine_fps_arms.py` verifies real-source provenance, deterministic output,
unchanged binds/materials/images, valid normals/weights and rejection of unknown
source bytes. Godot separately tests posed grip and open shoulder boundaries;
native screenshots remain necessary to assess visual quality.


## v0.36 combat expansion — Quaternius original CC0 GLBs

Author: Quaternius. License: CC0 1.0, commercial redistribution permitted.
Publisher pages: https://quaternius.com/packs/toonshootergamekit.html and https://quaternius.com/packs/ultimatedanimatedcharacter.html .
These are explicitly stylized original models, not photorealistic weapons. The original M4A1 remains the default rifle.
Binary mirror pinned to Papyszoo/CC0-Public-Domain-Models revision `77343cac874f06b73d16ad0063339df7c9ca254c`.
No source triangles, materials, UVs, skins or animations are replaced. Runtime fitting, per-seat assignment and attachment transforms are game changes.

| File | Original path | Bytes | Git blob SHA-1 | SHA-256 |
|---|---|---:|---|---|
| fps_pistol.glb | packs/quaternius-toonshootergamekit/models/pistol/pistol.glb | 43200 | 2c972f6318e7e276b567d4f84d1d297784e298a8 | e2e04925cd7da2a2277dcc2cc786462bf4181990af9d19b169a87fc32c734f3b |
| fps_sniper.glb | packs/quaternius-toonshootergamekit/models/sniper/sniper.glb | 86056 | c2f7b16ea97fd17c008601f59ce2eb4a644b261b | a4515fd68ece765d4995fe4ec21d2bc19ffb86490cfb96b5a34036b318e8ea11 |
| fps_knife.glb | packs/quaternius-toonshootergamekit/models/knife_1/knife_1.glb | 25600 | 5165f88031503caf681e76384f2932e9f50547c5 | caccc1bab73bfa2825e8011e6498a45c1cc411a9ea938800d5c805bfc043ac27 |
| fps_character_1.glb | packs/quaternius-ultimatedanimatedcharacter/models/soldier_male/soldier_male.glb | 1094616 | 08a6194c43a2b1c9c07f60e58a3d9045b3ca4d39 | 8cac948b84679ad73917d026708a55ebbdfacc9a195a392556019cdd05cc2c8c |
| fps_character_2.glb | packs/quaternius-ultimatedanimatedcharacter/models/blue_soldier_female/blue_soldier_female.glb | 1302704 | 3f7a5a238ea43df29082314e28b3b16b410e87ec | 2f2340c049c1f3070ceb0f32dd164c9f724b504adeca9122a9186f1cc3f7627a |
| fps_character_3.glb | packs/quaternius-ultimatedanimatedcharacter/models/ninja_male/ninja_male.glb | 1079144 | 173af51c2ca03aa759f16e93c47eb2dfaea7cdb5 | 1771452716515ef03d4760f45500ab68a705cbee8fec074a63b3c33fddf93920 |
| fps_character_4.glb | packs/quaternius-ultimatedanimatedcharacter/models/ninja_sand_female/ninja_sand_female.glb | 1313224 | 0c714b663b22f345b621e5671516828fbf6d2a5b | 23366e9df98b34d404cde1468b895ed71a577aed1ad042c279157b7515ac4058 |

## v0.37 SIGNAL interface art
Original repository-native vector drawing code in backrooms_interface_art.gd,
backrooms_interface_button.gd and backrooms_interface_theme.gd: sector atlas,
signal routes, corner marks, checkbox/slider glyphs and joystick. Authored for
FACELESS 2 / Zorix GAme Team; no downloaded art or generated raster assets.
Typography retains the source-verified Noto Sans SC (OFL 1.1) described above.

## v0.38 own-code derivatives
Four-sector map layout and animated SIGNAL atlas/scanner are repository-authored
code. New sectors reuse the existing verified original Kenney/Poly Haven GLBs/PBR
without changing source hashes. Seats 5/6 reuse Quaternius source characters 1/2
with original runtime cyan/copper material tint derivatives; meshes, skins, UVs
and source licenses are preserved. No newly downloaded or AI-generated models.
