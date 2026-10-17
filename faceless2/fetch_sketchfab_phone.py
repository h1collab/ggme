#!/usr/bin/env python3
"""Fetch licensed Sketchfab iPhone 17 Pro glTF with a CI-only access token.

The public model metadata is checked before downloading; no token, signed URL,
or temporary unlicensed model archive is ever committed or logged.
"""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen
import zipfile
import io

MODEL_UID = "4541aa8a28324b33a2baaf81d263aaec"
SOURCE_URL = "https://sketchfab.com/3d-models/iphone-17-pro-" + MODEL_UID
API = "https://api.sketchfab.com/v3/models/" + MODEL_UID
MAX_ARCHIVE = 85 * 1024 * 1024
MAX_EXTRACTED = 180 * 1024 * 1024


def get_json(url: str, token: str | None = None) -> dict:
    headers = {"User-Agent": "Faceless2AssetBuild/0.19", "Accept": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    with urlopen(Request(url, headers=headers), timeout=45) as response:
        return json.load(response)


def retrieve(url: str) -> bytes:
    # Archive URLs are time-limited; never print them to CI logs.
    with urlopen(Request(url, headers={"User-Agent": "Faceless2AssetBuild/0.19"}), timeout=90) as response:
        data = response.read(MAX_ARCHIVE + 1)
    if len(data) > MAX_ARCHIVE:
        raise RuntimeError("Sketchfab archive exceeds the mobile asset budget")
    return data


def check_license(info: dict) -> None:
    license_info = info.get("license") or {}
    url = str(license_info.get("url") or "").lower().rstrip("/")
    label = str(license_info.get("label") or "").lower()
    # Commercial redistribution in a game is permitted by CC BY 4.0.
    # Do not silently accept CC BY-NC, CC BY-ND, custom or unknown licenses.
    if "creativecommons.org/licenses/by/4.0" not in url and "cc attribution" not in label:
        raise RuntimeError("Sketchfab source is not clearly licensed CC BY 4.0")
    if "noncommercial" in label or "no derivatives" in label or "/by-nc" in url or "/by-nd" in url:
        raise RuntimeError("Sketchfab license would forbid this game's distribution")
    if info.get("isDownloadable") is False:
        raise RuntimeError("Artist disabled downloads for the chosen model")


def main() -> int:
    output = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("app/assets/vendor")
    output.mkdir(parents=True, exist_ok=True)
    token = os.environ.get("SKETCHFAB_TOKEN", "").strip()
    if not token:
        print("SKETCHFAB_STATUS=fallback: no configured Actions access token; original licensed phone retained")
        return 0

    try:
        metadata = get_json(API, token)
        if str(metadata.get("uid", MODEL_UID)) != MODEL_UID:
            raise RuntimeError("Sketchfab returned unexpected model identity")
        check_license(metadata)
        link = get_json(API + "/download", token).get("gltf", {}).get("url")
        if not link:
            raise RuntimeError("Sketchfab has no authorized glTF download for this model")
        binary = retrieve(str(link))
        with zipfile.ZipFile(io.BytesIO(binary)) as archive, tempfile.TemporaryDirectory(prefix="iphone17_") as directory:
            root = Path(directory)
            names = [n for n in archive.namelist() if not n.endswith("/")]
            if len(names) > 400:
                raise RuntimeError("Unusually large Sketchfab archive")
            if sum(archive.getinfo(n).file_size for n in names) > MAX_EXTRACTED:
                raise RuntimeError("Extracted Sketchfab files exceed budget")
            for n in names:
                relative = Path(n)
                if relative.is_absolute() or ".." in relative.parts:
                    raise RuntimeError("Unsafe path in Sketchfab ZIP")
                destination = root / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                with archive.open(n) as src, destination.open("wb") as target:
                    target.write(src.read())
            scenes = sorted(root.rglob("*.gltf"))
            if not scenes:
                raise RuntimeError("Sketchfab did not provide a glTF scene")
            target = output / "iphone17_pro.glb"
            subprocess.run(
                ["npx", "--yes", "@gltf-transform/cli@4.5.1", "copy", str(scenes[0]), str(target)],
                check=True, timeout=240
            )
            if not target.is_file() or target.stat().st_size < 4096 or target.read_bytes()[:4] != b"glTF":
                raise RuntimeError("iPhone 17 GLB export is missing or malformed")
            (output / "iphone17_pro.source.json").write_text(
                json.dumps(
                    {"model_uid": MODEL_UID, "source": SOURCE_URL, "author": (metadata.get("user") or {}).get("displayName", "Ranguel"), "license": "CC BY 4.0", "sha256": hashlib.sha256(target.read_bytes()).hexdigest()},
                    indent=2
                )
            )
            print("SKETCHFAB_STATUS=real-licensed-iphone17-glb")
            print("SKETCHFAB_MODEL_SHA256=" + hashlib.sha256(target.read_bytes()).hexdigest())
    except (HTTPError, URLError) as exc:
        # Intentionally avoid repr(exc), which may include secret signed URLs.
        raise RuntimeError("Sketchfab authenticated download failed; check token scopes, expiry and authorized model access") from None
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as error:
        print("SKETCHFAB_ERROR: " + str(error), file=sys.stderr)
        raise SystemExit(1)
