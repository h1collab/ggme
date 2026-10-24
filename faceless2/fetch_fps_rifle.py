"""Import nisu / 3DModelsCC0's original M4A1 release, never a game rip.

Publisher listing: https://opengameart.org/content/m4a1-assault-rifle (CC0).
Original author URL is now unavailable; the publisher-hosted 2022 ZIP remains.
Pin the complete original ZIP AND each extracted source file. Godot's native
ufbx importer and GLTFDocument convert those authored triangles on the build.
"""
import hashlib
import io
import sys
import urllib.request
import zipfile
from pathlib import Path

URL = "https://opengameart.org/sites/default/files/m4a1_0.zip"
ZIP_SHA256 = "ed5779ec82718861964227e2aad2a900978ea087081154365d6d86246be62f0d"
FILES = {
    "M4A1.fbx": (278384,"d66516a3455b975027556394b9afb92a1e9093d700ccf779aab223cd6ac4076e"),
    "M4A1_Base_Color.png": (518307,"e28fb02a6a1d951ec2d356fad8f267ba04da7d294bfa001eb3995549971e1b34"),
    "M4A1_Height.png": (11516,"df12e21e2c5a8553bb7b5e9bee80477a123f3c5cda5cf55d50d739f69a51b904"),
    "M4A1_Metallic.png": (308597,"e9cc71ff7886c552030586c650e67c78a86c8b2a812357e40edc19d5bc9426ca"),
    "M4A1_Normal.png": (973345,"9da0b6da232cc676482eeb2b21fdfe04f03504a0e37407f3bbc35556335bd998"),
    "M4A1_Roughness.png": (1600615,"708eff9df647f0ecf258467e983052e164286d1dc579e763a6d8261074d3eb9a"),
}

def main(folder: Path) -> None:
    folder = folder/"m4a1_source"
    folder.mkdir(parents=True,exist_ok=True)
    if not all((folder/name).is_file() and (folder/name).stat().st_size == size
               and hashlib.sha256((folder/name).read_bytes()).hexdigest() == sha
               for name,(size,sha) in FILES.items()):
        request = urllib.request.Request(URL,headers={"User-Agent":"Faceless2-CC0-source-verification"})
        with urllib.request.urlopen(request,timeout=90) as response: raw = response.read(5000000)
        if hashlib.sha256(raw).hexdigest() != ZIP_SHA256:
            raise ValueError("Publisher M4A1 ZIP SHA-256 mismatch")
        with zipfile.ZipFile(io.BytesIO(raw)) as archive:
            if archive.testzip(): raise ValueError("Publisher M4A1 ZIP CRC error")
            for name,(size,sha) in FILES.items():
                content = archive.read("M4A1/"+name)
                if len(content) != size or hashlib.sha256(content).hexdigest() != sha:
                    raise ValueError("Publisher M4A1 source mismatch: "+name)
                (folder/name).write_bytes(content)
    print("FPS_CC0_M4A1_SOURCE_PASS",ZIP_SHA256)

if __name__ == "__main__": main(Path(sys.argv[1]))
