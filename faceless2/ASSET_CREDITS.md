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
