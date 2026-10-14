"""Fetch ORIGINAL Kenney Blaster Kit CC0 GLBs for Faceless 2's FPS loop.

Publisher: https://kenney.nl/assets/blaster-kit ; CC0 1.0 commercial reuse.
Pinned converted GLB mirror: Papyszoo/CC0-Public-Domain-Models.
Verify exact binary length, Git object SHA-1, SHA-256, GLB header and declared
chunk length. No generative/replacement geometry; do not bypass validation.
"""
from __future__ import annotations

import hashlib
import sys
import urllib.request
from pathlib import Path

REV = "77343cac874f06b73d16ad0063339df7c9ca254c"
ROOT = ("https://raw.githubusercontent.com/Papyszoo/CC0-Public-Domain-Models/"
        + REV + "/packs/kenney-blaster-kit/models")
MODELS = {
    "fps_blaster_f": ("blaster_f", 82676,
        "54c9c7988cec2294c9d8ef4b5cfcbf125a76f76e",
        "e1fd9bb8839cc60d26bd12d5093cadccda22943b29db6c5846f8e9ec66309868"),
    "fps_target_large": ("target_large", 17792,
        "c9dabfded68fd9693cad975bb5abc30af9503b4c",
        "92cd7fb5faaaa0a118fccb9c374121fd56dd7f5bf16d9842c7114c243ae74be4"),
    "fps_clip_small": ("clip_small", 18036,
        "22d033e4c07177f09a951cf06e3cf926d19ecb87",
        "cf282a14a7cbe5de85a5977a144240d4343faf4f70b37d24d53624f91a738740"),
}

def verify(data: bytes, name: str) -> None:
    _, size, git_sha, sha256 = MODELS[name]
    if len(data) != size or data[:4] != b"glTF" or int.from_bytes(data[8:12], "little") != len(data):
        raise ValueError("Kenney original GLB length/header mismatch: " + name)
    git_object = b"blob " + str(len(data)).encode("ascii") + b"\0" + data
    if hashlib.sha1(git_object).hexdigest() != git_sha:
        raise ValueError("Kenney original GLB git object changed: " + name)
    if hashlib.sha256(data).hexdigest() != sha256:
        raise ValueError("Kenney original GLB SHA-256 changed: " + name)

# WRAD ARMS by wriks, original fully skinned/rigged FPS GLB, CC0 1.0.
# https://github.com/wwwriks/wrad-arms/blob/f3987244176c33d2c20d4f9e139980af12684d87/arms.glb
# License: https://github.com/wwwriks/wrad-arms/blob/f3987244176c33d2c20d4f9e139980af12684d87/LICENSE
# Commercial redistribution and authored skeleton reposing are permitted.
ARMS_REV = "f3987244176c33d2c20d4f9e139980af12684d87"
ARMS_URL = "https://raw.githubusercontent.com/wwwriks/wrad-arms/" + ARMS_REV + "/arms.glb"
ARMS_LENGTH = 456328
ARMS_GIT_BLOB = "be023c46705bf8571e9ab97dbd3e71d2f18f8473"
ARMS_SHA256 = "580efbb0852bf0b41f82dd3e17eafec86b3d2a48f4a7acaa7e64d60e850f565d"

def verify_wrad_arms(data: bytes) -> None:
    if len(data) != ARMS_LENGTH or data[:4] != b"glTF" or int.from_bytes(data[8:12], "little") != len(data):
        raise ValueError("WRAD original arm GLB size/format differs from the licensed source")
    obj = b"blob " + str(len(data)).encode() + b"\0" + data
    if hashlib.sha1(obj).hexdigest() != ARMS_GIT_BLOB or hashlib.sha256(data).hexdigest() != ARMS_SHA256:
        raise ValueError("WRAD original author GLB does not match fixed Git and SHA-256 hashes")
    # GLB source is a real authored skinned model; not a stand-in cube.
    import json
    json_len = int.from_bytes(data[12:16], "little")
    src = json.loads(data[20:20+json_len])
    if not src.get("skins") or not any(n.get("name") == "arms_mesh" for n in src.get("nodes", [])):
        raise ValueError("WRAD original source no longer contains authored skeleton/skin")

def fetch_wrad_arms(folder: Path) -> None:
    dest = folder / "fps_wrad_arms.glb"
    if dest.exists():
        verify_wrad_arms(dest.read_bytes())
    else:
        request = urllib.request.Request(ARMS_URL,headers={"User-Agent":"Faceless2-CC0-WRAD-Arms"})
        with urllib.request.urlopen(request,timeout=75) as handle:
            raw = handle.read(600000)
        verify_wrad_arms(raw)
        dest.write_bytes(raw)
    print("FPS_WRAD_CC0_SKINNED_ARMS_PASS",ARMS_SHA256)
    from bake_fps_grip_hands import bake
    subset = folder / "fps_wrad_grip_hands.glb"
    triangles, original = bake(dest,subset)
    if not (1160 <= triangles <= 1190 and original > triangles):
        raise ValueError("CC0 hand/wrist GLB subset count invalid")
    print("FPS_WRAD_CC0_SKINNED_GRIP_PASS",triangles,original)
    for side in ("r", "l"):
        target = folder / ("fps_wrad_grip_" + side + ".glb")
        hand_triangles,_ = bake(dest,target,side)
        if hand_triangles < 570 or hand_triangles > 600:
            raise ValueError("Original WRAD authored hand subset has unexpected count: "+side)
        print("FPS_WRAD_HAND_SIDE_PASS",side,hand_triangles)

def main(folder: Path) -> None:
    folder.mkdir(parents=True, exist_ok=True)
    for output, (model, _, _, sha256) in MODELS.items():
        dest = folder / (output + ".glb")
        if dest.is_file():
            try:
                verify(dest.read_bytes(), output)
                print("FPS_ORIGINAL_GLB_PASS", output, sha256)
                continue
            except ValueError:
                dest.unlink()
        url = f"{ROOT}/{model}/{model}.glb"
        request = urllib.request.Request(url, headers={"User-Agent": "Faceless2-CC0-FPS-Import"})
        with urllib.request.urlopen(request, timeout=75) as handle:
            raw = handle.read(250000)
        verify(raw, output)
        dest.write_bytes(raw)
        print("FPS_ORIGINAL_GLB_PASS", output, sha256)
    fetch_wrad_arms(folder)

if __name__ == "__main__":
    main(Path(sys.argv[1] if len(sys.argv) > 1 else "app/assets/vendor"))
