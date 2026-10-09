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

## Build and verification

The workflow downloads the original licensed GLBs using the existing
`SKETCHFAB_TOKEN` repository secret, imports them and runs these regressions
before exporting the APK:

```sh
godot --headless --path app --script scripts/rendering_checks.gd
```

The checks cover road normals and collision alignment, visible weapon scale
and axis, touch aiming, selected FOV, ammunition, reset during reload and
soldier scale preservation. Local visual QA uses the original imported assets
from the existing APK. Android hardware frame rate and touch ergonomics still
need device testing; software renderer screenshots do not establish a phone
performance target. This is an improvement to a prototype, not a claim of
finished AAA production quality.

PC controls: WASD move, Shift run, C crouch, F flashlight, left mouse/Space fire,
right mouse aim, R reload, Q switch, E interact. Android uses the joystick and
labelled action buttons. Story, rush, nightmare, exploration and blackout modes,
relay objectives, evidence, radio scenes and checkpoint saves are retained.
