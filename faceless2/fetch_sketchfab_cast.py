#!/usr/bin/env python3
"""Authorized import of two Sketchfab CC BY 4.0 assets, to build-time GLB.

Never scrape the Sketchfab viewer, never print OAuth credentials or signed URLs.
Fails closed when the authorized Download API isn't available; the game must not
silently fall back to primitives/old non-Sketchfab characters.
"""
from __future__ import annotations

import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen
from zipfile import ZipFile

ASSETS = {
    "smiler": {
        "uid": "902975161a7047baa5cda8fb7b5a292e",
        "title": "Accurate Smiler Backrooms Blender 3.22",
        "creator": "Speed12",
        "source": "https://sketchfab.com/3d-models/accurate-smiler-backrooms-blender-322-902975161a7047baa5cda8fb7b5a292e",
        "filename": "sketchfab_smiler.glb",
    },
    "arms": {
        "uid": "e3c42c05b22944e5839deb8e003f0987",
        "title": "First Person arms",
        "creator": "DJMaesen",
        "source": "https://sketchfab.com/3d-models/first-person-arms-e3c42c05b22944e5839deb8e003f0987",
        "filename": "sketchfab_fps_arms.glb",
    },
}

LIMIT = 130 * 1024 * 1024
API = "https://api.sketchfab.com/v3/models/"

def json_get(url: str, header: str = "") -> dict:
    headers = {"User-Agent": "Faceless2AuthorizedAssetImporter/0.22", "Accept": "application/json"}
    if header:
        headers["Authorization"] = header
    with urlopen(Request(url, headers=headers), timeout=65) as response:
        return json.load(response)

def download_zip(url: str) -> bytes:
    # Never log or persist the short-lived signed URL.
    with urlopen(Request(url, headers={"User-Agent": "Faceless2AuthorizedAssetImporter/0.22"}), timeout=100) as response:
        data = response.read(LIMIT + 1)
    if len(data) > LIMIT or len(data) < 300:
        raise RuntimeError("Sketchfab model download is empty or exceeds the mobile download budget")
    return data

def check_metadata(info: dict, name: str) -> None:
    license_data = info.get("license") or {}
    license_url = str(license_data.get("url") or "").lower()
    license_label = str(license_data.get("label") or "").lower()
    if "creativecommons.org/licenses/by/4.0" not in license_url:
        raise RuntimeError(name + ": model no longer carries verifiable CC BY 4.0 license")
    if "/by-nc" in license_url or "/by-nd" in license_url or "noncommercial" in license_label:
        raise RuntimeError(name + ": license is incompatible with commercial redistribution")
    if info.get("isDownloadable") is False:
        raise RuntimeError(name + ": the author disabled authorized downloads")

def check_creator(info: dict, item: dict) -> None:
    # UID and license do not establish attribution if ownership changed.
    user = info.get("user") or {}
    names = {str(user.get(key) or "").strip().casefold()
             for key in ("username", "displayName")}
    names.discard("")
    if names and item["creator"].casefold() not in names:
        raise RuntimeError(item["title"] + ": original Sketchfab creator identity changed")


def download_authorized(uid: str, token: str) -> dict:
    # OAuth access tokens require Bearer; a legacy user API token can be Token.
    errors = []
    for method in ("Bearer", "Token"):
        try:
            answer = json_get(API + uid + "/download", method + " " + token)
            if isinstance(answer.get("gltf"), dict) and answer["gltf"].get("url"):
                return answer
            errors.append(method + "=no-gltf")
        except HTTPError as exc:
            errors.append(method + "=" + str(exc.code))
        except (URLError, TimeoutError):
            errors.append(method + "=unreachable")
    raise RuntimeError("Sketchfab download access refused (" + ", ".join(errors) + "). "
                       "Set an unexpired user OAuth access token with model-download permission in GitHub Actions "
                       "SKETCHFAB_TOKEN; an API upload token alone may not grant Download API access")

def read_gltf_archive(data: bytes, temp: Path) -> Path:
    with ZipFile(io.BytesIO(data)) as archive:
        infos = [info for info in archive.infolist() if not info.is_dir()]
        if len(infos) > 250 or sum(info.file_size for info in infos) > 300 * 1024 * 1024:
            raise RuntimeError("Sketchfab archive is unexpectedly large")
        for item in infos:
            dest = temp / item.filename
            if ".." in Path(item.filename).parts or Path(item.filename).is_absolute():
                raise RuntimeError("Unsafe path in authorized Sketchfab archive")
            dest.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(item) as source, dest.open("wb") as target:
                while True:
                    chunk = source.read(1 << 20)
                    if not chunk:
                        break
                    target.write(chunk)
    scenes = sorted(temp.rglob("*.gltf"))
    if not scenes:
        raise RuntimeError("Download did not contain Sketchfab glTF scene")
    return scenes[0]

def convert_asset(item: dict, folder: Path, token: str) -> None:
    uid = item["uid"]
    metadata = json_get(API + uid)  # Public, non-secret metadata.
    if metadata.get("uid") and str(metadata["uid"]) != uid:
        raise RuntimeError("Unrecognized Sketchfab model returned for " + item["title"])
    check_metadata(metadata, item["title"])
    check_creator(metadata, item)
    manifest = folder / (item["filename"] + ".source.json")
    target = folder / item["filename"]
    info = download_authorized(uid, token)
    data = download_zip(str(info["gltf"]["url"]))
    source_archive_sha256 = hashlib.sha256(data).hexdigest()
    with tempfile.TemporaryDirectory(prefix="faceless_sketchfab_") as tmp:
        scene = read_gltf_archive(data, Path(tmp))
        subprocess.run(
            ["npx", "--yes", "@gltf-transform/cli@4.5.1", "copy",
             str(scene), str(target)],
            check=True, timeout=240,
            stdout=subprocess.DEVNULL,
        )
    binary = target.read_bytes()
    if len(binary) < 2048 or binary[:4] != b"glTF":
        raise RuntimeError("Authorized " + item["title"] + " GLB conversion invalid")
    digest = hashlib.sha256(binary).hexdigest()
    manifest.write_text(json.dumps({
        "sketchfab_uid": uid,
        "original_title": item["title"],
        "creator": item["creator"],
        "source": item["source"],
        "license": "CC BY 4.0",
        "sha256": digest,
        "size": len(binary),
        "authorized_source_archive_sha256": source_archive_sha256,
        "authorized_source_archive_size": len(data)
    }, indent=2, ensure_ascii=False) + "\n")
    print("SKETCHFAB_AUTHORIZED_GLB_PASS", item["filename"], len(binary), digest)

def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: fetch_sketchfab_cast.py OUTPUT_VENDOR_DIRECTORY", file=sys.stderr)
        return 2
    token = (os.environ.get("SKETCHFAB_TOKEN") or
             os.environ.get("SKETCHFAB_OAUTH_TOKEN") or
             os.environ.get("SKETCHFAB_ACCESS_TOKEN") or "").strip()
    if not token:
        print("SKETCHFAB_AUTH_REQUIRED: Missing authorized user download token; neither "
              "Sketchfab Smiler nor Sketchfab arms will be substituted", file=sys.stderr)
        return 2
    folder = Path(sys.argv[1])
    folder.mkdir(parents=True, exist_ok=True)
    for name, item in ASSETS.items():
        try:
            convert_asset(item, folder, token)
        except (HTTPError, URLError) as exc:
            code = exc.code if isinstance(exc, HTTPError) else "network"
            print("SKETCHFAB_ASSET_ERROR: " + name + " API request failed (" + str(code) +
                  "); credentials and signed URLs are not logged", file=sys.stderr)
            return 1
        except (RuntimeError, subprocess.CalledProcessError) as exc:
            print("SKETCHFAB_ASSET_ERROR: " + name + ": " + str(exc), file=sys.stderr)
            return 1
    print("Sketchfab cast GLB inventory: PASS / genuine Smiler and first-person arms")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
