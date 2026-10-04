#!/usr/bin/env python3
import json, os, shutil, subprocess, sys, tempfile, urllib.request, urllib.error, zipfile, time
from pathlib import Path

ROOT = Path(__file__).resolve().parent
manifest_path = ROOT / "sketchfab_assets.json"
out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "downloaded_assets"
token = os.environ.get("SKETCHFAB_TOKEN", "").strip()
if not token:
    raise SystemExit("SKETCHFAB_TOKEN is required. Add your Sketchfab API token as a GitHub Actions repository secret.")

manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
out_dir.mkdir(parents=True, exist_ok=True)
cache = {}
_last_api_call = 0.0

def api_json(url):
    global _last_api_call
    # Sketchfab may rate-limit model download URL requests. Keep calls under ~12/min.
    wait = 5.2 - (time.monotonic() - _last_api_call)
    if wait > 0:
        time.sleep(wait)
    for attempt in range(8):
        req = urllib.request.Request(
            url,
            headers={
                "Authorization": f"Token {token}",
                "User-Agent": "Faceless2-Zorix/1.0",
                "Accept": "application/json",
            },
        )
        try:
            _last_api_call = time.monotonic()
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            if e.code != 429 or attempt >= 7:
                raise
            retry_after = e.headers.get("Retry-After")
            try:
                delay = max(15.0, float(retry_after)) if retry_after else 30.0 * (attempt + 1)
            except ValueError:
                delay = 30.0 * (attempt + 1)
            print(f"Sketchfab rate limit hit; retrying in {delay:.0f}s (attempt {attempt+1}/8)", flush=True)
            time.sleep(delay)
    raise RuntimeError("Sketchfab download API retries exhausted")

def download(url, path):
    req = urllib.request.Request(url, headers={"User-Agent": "Faceless2-Zorix/1.0"})
    with urllib.request.urlopen(req, timeout=180) as r, open(path, "wb") as f:
        shutil.copyfileobj(r, f)

def convert_gltf_to_glb(src, dst):
    subprocess.check_call(["npx", "--yes", "@gltf-transform/cli", "copy", str(src), str(dst)])

for item in manifest["assets"]:
    uid = item["uid"]
    target = out_dir / item["output"]
    if uid in cache:
        shutil.copy2(cache[uid], target)
        print("reused", item["output"], "<-", uid)
        continue

    info = api_json(f"https://api.sketchfab.com/v3/models/{uid}/download")
    selected = None
    for key in ("gltf", "original"):
        entry = info.get(key)
        if entry and entry.get("url"):
            selected = (key, entry)
            break
    if selected is None:
        raise RuntimeError(f"No downloadable glTF/original archive for {uid} ({item['name']})")

    with tempfile.TemporaryDirectory() as td:
        td = Path(td)
        archive = td / "asset.zip"
        download(selected[1]["url"], archive)
        if not zipfile.is_zipfile(archive):
            raise RuntimeError(f"Expected zip download for {uid}")
        with zipfile.ZipFile(archive) as z:
            z.extractall(td / "unzipped")
        files = list((td / "unzipped").rglob("*"))
        glbs = [p for p in files if p.suffix.lower() == ".glb"]
        gltfs = [p for p in files if p.suffix.lower() == ".gltf"]
        if glbs:
            shutil.copy2(glbs[0], target)
        elif gltfs:
            convert_gltf_to_glb(gltfs[0], target)
        else:
            raise RuntimeError(f"No .glb/.gltf found in Sketchfab download for {uid}")

    cache[uid] = target
    if target.stat().st_size < 1024:
        raise RuntimeError(f"Suspiciously small GLB: {target}")
    print("downloaded", item["output"], target.stat().st_size)

credits = out_dir / "SKETCHFAB_CREDITS.txt"
with credits.open("w", encoding="utf-8") as f:
    f.write("FACELESS 2 — Sketchfab asset credits\n\n")
    for item in manifest["assets"]:
        f.write(f"{item['name']} — {item['author']} — {item['license']}\n{item['url']}\n\n")
print("credits", credits)
