"""Download genuine Kenney CC0 glTF-Binary modules for the underground wake-up set.

Inputs are pinned to the publicly credited CC0 pack. Verify exact Git blob
hash + expected size, then sanity-check the GLB header; never substitute boxes.
"""
from __future__ import annotations
import hashlib
import sys
import urllib.request
from pathlib import Path

SOURCE = "https://github.com/Papyszoo/CC0-Public-Domain-Models"
REV = "77343cac874f06b73d16ad0063339df7c9ca254c"
ROOT = f"https://raw.githubusercontent.com/Papyszoo/CC0-Public-Domain-Models/{REV}/packs/kenney-space-station-kit/models"
MODELS = {
    "floor_panel": ("9390db0076481208a69600a9cf5bd9c1c21eee69", 16344),
    "wall": ("0a642a26354c72f8e35e87be0ffe39f3bb274cd2", 12696),
    "wall_pillar": ("852f576f656ce36f223d96603b3b78e55e357de5", 16668),
    "wall_window": ("8273b618cba4b995ca79a4badcc2b3addff46207", 17160),
    "door_single_closed": ("5cfac024f3722db51caf2ab5ec1d8095e336377a", 14420),
    "pipe": ("fbda2abd4699a2f16f4004d905a1f2951bd18119", 10976),
    "computer_screen": ("1c59a7606a6d2a7da56eaac061cee23c5960aa9b", 27028),
    "display_wall": ("67281897a05455e79b30d6a173bbaa63da18df29", 16216),
    "container_tall": ("74ad63aa022d7d4435c87218422575277a610c36", 20492),
    "structure_panel": ("382b5b4a4cac8732755d2a65c05e00735e7afd61", 19956),
    "wall_door": ("f93c167cd5ed23d2a7d7e6f7b4a2b19853a36211", 17332),
    "wall_switch": ("afd544793eb363d788dc195c3af319d03384a2fc", 10632),
    "chair": ("e10229e50bbb4a737656c27df65451fa7b0cfd82", 14392),
}

def verify(data: bytes, expected: str, size: int) -> None:
    assert len(data) == size and data[:4] == b"glTF", "Bad or truncated authored GLB"
    # Git blob hash differs from ordinary SHA-1 by the Git object prefix.
    blob = b"blob " + str(len(data)).encode("ascii") + bytes([0]) + data
    assert hashlib.sha1(blob).hexdigest() == expected, "Upstream CC0 model hash changed"

def main(destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    for name, (sha, size) in MODELS.items():
        path = destination / f"wakeup_{name}.glb"
        if path.exists():
            try:
                verify(path.read_bytes(), sha, size)
                continue
            except AssertionError:
                path.unlink()
        url = f"{ROOT}/{name}/{name}.glb"
        with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Faceless2-CC0-asset-build"}), timeout=60) as resp:
            data = resp.read(1_000_000)
        verify(data, sha, size)
        path.write_bytes(data)
        print(f"WAKEUP_GLB_PASS {name} {size} bytes")
    print(f"Faceless 2 wake-up GLB inventory: PASS / {len(MODELS)} Kenney CC0 authentic models")

if __name__ == "__main__":
    main(Path(sys.argv[1] if len(sys.argv) > 1 else "app/assets/vendor"))
