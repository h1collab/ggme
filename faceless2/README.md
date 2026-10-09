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
- Android build output is `faceless-2-v7-zorix.apk`, version code 7 / name 0.7.0.

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
