# FACELESS 2 v0.35 reviewed build

Game source: `637e79095b7b2026dd74d9b02550e21a4ae2aeb2` on `fix/faceless2-rendering-polish`. PR #1 remains open. This QA branch preserves evidence; it is not a different game release.

Android CI: https://github.com/h1collab/ggme/actions/runs/38911613127
Native desktop CI: https://github.com/h1collab/ggme/actions/runs/38911613143
Both succeeded for exactly the source SHA above. The independent audit downloads those immutable artifacts, checks CRC, manifest 0.35.0/code35, 293 imported references, real headless/UDP results, video decoding and all 520 distinct frames.

APK itself: **236276943 bytes**; SHA-256 `a5c46609cb87ea163035d2f72a7b3c399eed9d16374cecd6276f0c1c589b14a8`.
APK artifact: https://github.com/h1collab/ggme/actions/runs/38911613127/artifacts/12051162300

Continuous Godot MP4: **3566112 bytes**, H.264 960×540, 20 FPS, 520 frames, 26 seconds, no audio. SHA-256 `5edbf0370eba9e9551436896843b318c697dde9fba137734fa362e2b105c7fd7`. Original video is copied unchanged into this folder. It is not a still montage; recording FPS is not Android performance.

Manual review completed after the first static report: inspect all 27 screenshot overview entries, five full-size JPEG representations of the original PNGs, and 52 video sample frames. Original PNGs copied here are unchanged. The reload grasp is now in view; the palm follows the source magazine base, and near-wall port arms retains the rifle. This is a simplified base-supported reload. Fingers/skin and repeated scene assets remain below AAA production quality; no zero-bug or all-poses zero-clipping claim.

Runtime/story/prologue/extra-level/cinematic/FPS/mobile, real Node directory, both maps × capacities 2/3/4, two-player start, ten actual kills, timeout/draw, ready/rematch reset, late join, invalid RPC, reload, disconnect/reconnect and LAN passed. Android device execution, sustained FPS, physical Wi-Fi/public NAT/relay and full anti-cheat remain unverified.

Local runtime became unavailable with `environment_offline`; final archive/manifest/hash/video inspection was executed by the independent Actions audit. Images were reviewed through the GitHub file connector.

Made By Zorix GAme Team
https://zorix.it
