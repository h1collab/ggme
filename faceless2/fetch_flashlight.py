"""Fetch Poly Haven's human-made CC0 flashlight glTF and package an actual GLB.

License: Poly Haven / Abiyyu Panggalih, Small Plastic Torch, CC0.
Each CDN download is verified against the publisher's MD5 and byte size.
Final GLB SHA-256 is written into the packaged ASSET_CREDITS.md and QA log.
"""
import hashlib
import json
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request
from pathlib import Path

ASSET = "small_plastic_torch"
AUTHOR = "Abiyyu Panggalih"
MANIFEST = "https://api.polyhaven.com/files/" + ASSET
SOURCE = "https://polyhaven.com/a/" + ASSET
LIMIT = 40_000_000


def get_json(url):
    request = urllib.request.Request(url, headers={"User-Agent": "Faceless2-CC0-verified-import/0.25"})
    with urllib.request.urlopen(request, timeout=65) as response:
        return json.load(response)


def download(file_info, destination):
    url = str(file_info["url"])
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or parsed.hostname != "dl.polyhaven.org":
        raise ValueError("Unapproved asset download host: " + url)
    expected_size = int(file_info["size"])
    if not 64 <= expected_size <= LIMIT:
        raise ValueError("Unexpected external GLTF resource size: " + str(expected_size))
    request = urllib.request.Request(url, headers={"User-Agent": "Faceless2-CC0-verified-import/0.25"})
    with urllib.request.urlopen(request, timeout=90) as response:
        data = response.read(LIMIT + 1)
    actual_md5 = hashlib.md5(data).hexdigest()
    if len(data) != expected_size or actual_md5 != file_info["md5"]:
        raise ValueError("Publisher MD5/size mismatch: " + destination.name)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(data)
    print("POLYHAVEN_SOURCE_VERIFIED", destination.name, expected_size, actual_md5)


def fetch(destination, credits, qa):
    manifest = get_json(MANIFEST)
    variations = manifest["gltf"]
    variant = "1k" if "1k" in variations else ("2k" if "2k" in variations else sorted(variations)[0])
    primary = variations[variant]["gltf"]
    if not isinstance(primary.get("include", {}), dict):
        raise ValueError("Unsupported GLTF include manifest")
    destination.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="f2-polyhaven-") as tempdir:
        temp = Path(tempdir)
        main_filename = Path(urllib.parse.urlparse(primary["url"]).path).name
        if not main_filename.endswith(".gltf"):
            raise ValueError("Expected real glTF source, got " + main_filename)
        source_file = temp / main_filename
        download(primary, source_file)
        for relative_name, included in primary.get("include", {}).items():
            rel = Path(relative_name)
            if rel.is_absolute() or ".." in rel.parts:
                raise ValueError("Untrusted GLTF dependency path")
            download(included, temp / rel)
        document = json.loads(source_file.read_text(encoding="utf-8"))
        for subresource in [*document.get("buffers", []), *document.get("images", [])]:
            uri = str(subresource.get("uri", ""))
            if uri and not uri.startswith("data:") and not (temp / urllib.parse.unquote(uri)).is_file():
                raise ValueError("Missing original glTF dependency: " + uri)
        target = destination / "flashlight_cc0.glb"
        subprocess.run(["npx", "--yes", "@gltf-transform/cli@4.5.1", "cp", str(source_file), str(target)], check=True)
    data = target.read_bytes()
    if len(data) < 1024 or data[:4] != b"glTF":
        raise ValueError("Converted flashlight is not a GLB")
    digest = hashlib.sha256(data).hexdigest()
    entry = ("\n## v0.25 — Physical pickup flashlight (original third-party GLB)\n\n"
             f"- **Small Plastic Torch**, artist **{AUTHOR}**, published by **Poly Haven**: {SOURCE}. "
             "Creative Commons Zero 1.0 (CC0), commercial reuse and redistribution permitted: "
             "https://creativecommons.org/publicdomain/zero/1.0/. "
             "This is the artist's real glTF geometry, converted offline into a Godot GLB with "
             "gltf-transform (not procedural or AI-generated). "
             f"Publisher files were size/MD5-verified from {MANIFEST}, variant {variant}; "
             f"packaged `assets/vendor/flashlight_cc0.glb` SHA-256: `{digest}`, bytes: {len(data)}.\n")
    if credits.is_file():
        with credits.open("a", encoding="utf-8") as f:
            f.write(entry)
    if qa:
        Path(qa).parent.mkdir(parents=True, exist_ok=True)
        Path(qa).write_text(f"FLASHLIGHT_GLB_VERIFIED sha256={digest} bytes={len(data)} author={AUTHOR} license=CC0 source={SOURCE}\n")
    print("FLASHLIGHT_GLB_PASS", digest, len(data))


if __name__ == "__main__":
    fetch(Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3] if len(sys.argv) > 3 else "")
