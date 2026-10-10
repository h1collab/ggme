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
