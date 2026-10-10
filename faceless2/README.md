# FACELESS 2 — made by zorix

Godot 4.7.2 first-person surveillance horror for Android landscape play.
The active APK is built by `.github/workflows/faceless2-apk.yml`. The project
is assembled from the verified `v03/` base plus this directory; the repository
root project is the older Escape Black Pine prototype.

## Rendering and combat polish

- Continuous 150m road, upward normals and an exact y=0 collision surface.
  The original Sketchfab road material is reused; the source forest diorama
  no longer determines road scale or puts trees beneath the player.
- A transparent, separately lit first-person SubViewport preserves gun and
  hand visibility near walls, in fog and at every supported world FOV.
- Measure skinned assets in their actual skeleton pose, preserving imported
  transforms. Remove the G19 showcase duplicates; crop and pose the original
  hand geometry around each weapon. Asset preparation is specific to the
  fixed Sketchfab UIDs in `sketchfab_assets.json`.
- Stable recoil and sway, touch-and-hold rifle fire and aiming, single-press
  weapon switching, analog movement and FOV settings respected after aiming.
- Reset cancels old reload callbacks. Soldier hit reactions preserve imported
  scale; soldiers require a clear line of sight to damage the player.
- Cooler moonlight, warm lamps, lower flashlight exposure, shadow quality
  tiers, distance-limited lights/meshes and throttled objective UI updates.

## Interface and immersion pass

- Fitted 1600×900 interface within Android display safe areas, with verified
  16:9, ultrawide, 4:3 tablet and small-window bounds. The world fills the screen.
- Separate mission, compass, vitals and weapon panels; projected objective
  markers with distance and direction, contextual interaction and radio captions.
- Styled campaign menu, six mode cards, incident archive, pause/resume and
  settings that return to the correct menu. Brightness, visibility, FOV, look
  sensitivity, volume, quality, frame cap and touch opacity persist on disk.
- Touch controls hide during menus, death and cinematics. Independent touch IDs
  support movement, aiming and firing together; off-control releases reset the
  joystick. Emulated mouse input on phones cannot fire the weapon accidentally.
- Aim-sensitive reticle, hit/kill markers, low-ammo indication and edge damage
  feedback. Forearm sleeves cover cropped ends without replacing the hand rig.
- Skip cinematics with the screen button or Escape; hostile attacks suspend
  during shots. Footsteps and weapon tails use separate audio channels; enemy
  shots have spatial sound. Reloading restores FOV after leaving aim.
- Checkpoints preserve weapons, magazines/reserves, lateral position, collected
  evidence/pickups, story beats and final-wave state. New operations reset gear.

## v7 atmosphere and combat

- Static procedural moon/star sky with debanding, sky fog control, a cooler
  distant forest and 18/32/52/72 trees per quality tier. Original pine meshes are
  instanced into two shared batches rather than duplicated for each tree.
- Instanced road reflector posts, nearby relay labels and pulsing status lamps
  that turn green when restored. Secondary lamps are disabled in Performance.
- Bounded pools for eight tracers, eight impact emitters and 24 bullet marks;
  no growing lists of shot nodes/timers. First-person muzzle flash, smoother ADS,
  sprint stance, aim walking speed, movement spread and crouch/aim accuracy.
- Directional damage indicators and brief camera shake, plus headshot damage
  and critical hit feedback. Soldier shots have a visible tell and target a
  snapshot position: movement and cover can prevent damage. Hits interrupt tells.
- Soldiers use sight, view direction, last-known positions and nearby gunfire
  investigation. The Faceless entity also respects sight/cover and remembers a
  last-known position. Character normalization uses posed bounds, both enemies
  preserve their fitted scale after damage, and the imported Walk clip loops.
- Android build output is now `faceless-2-v8-zorix.apk`, version code 8 / name 0.8.0.

## v8 model polish and runtime QA

- `optimize_glb.py` repacks all 19 downloaded GLBs before Godot import. Hero models retain up to 2048px textures, scenery uses 1024px, and small interactive props use 512px. PNG alpha and packed PBR channels are preserved. Geometry, accessor indices, rigs and animations are unchanged; identical buffer payloads share aligned storage. The build publishes a per-model byte/texture report.
- World models use an outer gameplay anchor with a separate scaled visual pivot. The visible base and interaction position now coincide even when an imported origin is far away. This fixes unreachable rifle/pickup/gate interactions.
- The checkpoint booth has a sensible scale and roadside position. The tower's exhibition terrain and stationary civilian are removed. Booth, tower, bus shelter and cabin use the visible mesh for static collision, so doorways and the lookout underside remain open.
- Guards face the direction of their AI, hold an actual rifle in a ready stance, and use a lightweight procedural leg gait on their original rig instead of sliding in a T pose.
- Road/shoulder materials, foliage specular response, moon/ambient lighting and the rifle support-hand placement are adjusted for a more coherent night scene.
- Crouching changes the capsule height and tests headroom before standing. Pausing immediately disables the hidden viewmodel render target. A new game writes an initial checkpoint so dying before Relay 1 can recover.

The APK workflow runs three optimizer integrity tests, the existing rendering/combat regression suite, and `gameplay_checks.gd`. The latter runs real physics movement, boundary collision, crouch/headroom, the timed death recovery, all relay/evidence/rifle interactions, reload, final-wave death callbacks and extraction. It also captures six 1280×720 views with the Mobile Vulkan renderer in `visual_checks.gd` and publishes them in `faceless-2-v8-visual-qa`.

These are desktop engine/runtime tests with actual imported assets and software-rendered screenshots. They do not measure Android device frame rate or replace a hardware playthrough. The current guard gait is procedural, and the mixed source assets still need authored animations/material art for a production AAA result.

## Build and verification

The workflow downloads the original licensed GLBs using the existing
`SKETCHFAB_TOKEN` repository secret, imports them and runs these regressions
before exporting the APK:

```sh
godot --headless --path app --script scripts/rendering_checks.gd
```

The checks cover road normals and collision alignment, visible weapon scale
and axis, touch aiming, selected FOV, ammunition, reset during reload and
soldier scale preservation, layout bounds, simultaneous touch input, off-screen
release, pause/settings/cinematic transitions and settings/checkpoint round trips,
cover/vision, snapshot-shot dodging, shot interruption, headshot damage, Faceless
scale, stance accuracy, quality budgets and repeated-fire pool bounds.
Local visual QA uses the original imported assets
from the existing APK. Android hardware frame rate and touch ergonomics still
need device testing; software renderer screenshots do not establish a phone
performance target. This is an improvement to a prototype, not a claim of
finished AAA production quality.

PC controls: WASD move, Shift run, C crouch, F flashlight, left mouse/Space fire,
right mouse aim, R reload, Q switch, E interact. Android uses the joystick and
labelled action buttons. Story, rush, nightmare, exploration and blackout modes,
relay objectives, evidence, radio scenes and checkpoint saves are retained.

## v9 natural materials and Zorix branding

- Ground now samples the original photographic gravel in world coordinates, on one continuous road strip, two wheel tracks, restrained damp patches and separate earth/leaf-litter shoulders with rolling terrain beyond the accessible area. Small normal detail and varying roughness respond to lights; the collision surface stays at y=0.
- Imported guard face/mouth metalness is corrected to zero. Fabric roughness rises from 0.027–0.059 to 0.86; skin and eyes keep distinct roughness. Hit reactions use a small lean instead of scaling the character.
- Moonlight and ambient fill are more neutral, lamp light warmer, fog less dense and the moon smaller. High-quality mode allows one nearby lamp to cast a single projected spotlight shadow. Forest spacing varies deterministically, distant forest closes both horizons and reflectors follow the actual road edges. End barriers prevent walking beyond the collision strip; both are exercised by real-physics tests.
- Weapon lighting and hand color are less bright and saturated. Ammo moves above the touch controls, radio subtitles move away from the crosshair, and touch actions use RELOAD/CROUCH labels.
- Gameplay PackedScenes are loaded and retained before the first world frame, avoiding late GLB mesh/texture uploads during the transition to the weapon SubViewport. Both nearby and instanced distant foliage use matte reflections.
- The supplied game image becomes the Android icon. The second supplied image is the team logo. Startup says **Made By Zorix GAme Team**, can be skipped and finishes while the world is paused. Main menu uses the actual 3D checkpoint backdrop and includes About Us with the official `https://zorix.it` link.
- `presentation_checks.gd` verifies imported branding, startup timing/skip, About Us/back, fitted phone/tablet layouts and guard fabric/skin materials. The existing rendering/combat and real-physics gameplay suites remain required. Nine actual Mobile Vulkan views include startup, main menu, About Us and six gameplay views.
- Android output: `faceless-2-v9-zorix.apk`, version code 9 / name 0.9.0. QA screenshots and logs are published in `faceless-2-v9-visual-qa`. Desktop/software Vulkan captures do not establish physical Android device frame rates. Existing low-poly model geometry and procedural character animation still limit visual realism.

Visual QA pins and verifies the exact Mesa software driver used locally. For llvmpipe captures only, gravel is decoded to identical source pixels before sampling; physical GPUs retain exported compressed textures. Camera poses, models, shaders, lighting, quality and output resolution stay the same. Per-stage/per-frame progress is logged to distinguish loading from rendering stalls.

The project uses eight worker threads with a 1.0 low-priority thread ratio. This is a tested workaround for Mobile shader/pipeline compilation stalls on cold caches in this asset set (upstream report: https://github.com/godotengine/godot/issues/123060). Cold-cache captures are checked separately from warm-cache rendering; hardware Android performance remains unmeasured.
