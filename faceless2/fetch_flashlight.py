"""Fetch real CC0 Poly Haven vintage flashlight GLB for Faceless 2.

The source is a fixed Git revision; the exact Git blob hash is verified before
the imported mesh is added to the temporary Godot project.
"""
import hashlib
import sys
from pathlib import Path
from urllib.request import Request, urlopen

REV = "77343cac874f06b73d16ad0063339df7c9ca254c"
PATH = "packs/polyhaven-maritime-structures/models/vintage_flashlight/vintage_flashlight.glb"
BLOB_SHA1 = "97fb441fddb794656306fa211c8d706510ce874d"
SIZE = 1833128
URL = "https://raw.githubusercontent.com/Papyszoo/CC0-Public-Domain-Models/" + REV + "/" + PATH

def main() -> None:
    folder = Path(sys.argv[1] if len(sys.argv) > 1 else "app/assets/vendor")
    folder.mkdir(parents=True, exist_ok=True)
    dst = folder / "vintage_flashlight.glb"
    if dst.exists():
        data = dst.read_bytes()
    else:
        with urlopen(Request(URL, headers={"User-Agent": "Faceless2-CC0-flashlight"}), timeout=80) as source:
            data = source.read(SIZE+1)
    if len(data) != SIZE or data[:4] != b"glTF":
        raise RuntimeError("Authentic flashlight GLB missing or invalid")
    h = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
    if h != BLOB_SHA1:
        raise RuntimeError("Authentic flashlight upstream hash has changed")
    dst.write_bytes(data)
    print("FACELESS_FLASHLIGHT_GLB_PASS", len(data), hashlib.sha256(data).hexdigest())

if __name__ == "__main__":
    main()
