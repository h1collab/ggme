"""Fetch original Poly Haven CC0 scanned GLB props and 1K PBR textures.
All original source bytes are size/MD5 verified, final bytes SHA-256 logged.
Commercial redistribution allowed by CC0; no generated substitute geometry.
"""
import hashlib
import json
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

MODELS = {
    "Barrel_02": "Jorge Camacho",
    "cardboard_box_01": "Rahul Chaudhary",
    "modular_airduct_circular_01": "Riley Queen",
    "wheelchair_01": "Garreth Dean",
    "industrial_wall_lamp": "Kuutti Siitonen",
    # Human-authored CC0 scanned furniture/lighting for the brand-new sectors.
    "GothicBed_01": "Kirill Sannikov",
    "Chandelier_03": "Kirill Sannikov",
    "vintage_day_bed": "Aron Łyczek",
    "wooden_lantern_01": "James Ray Cock",
    "bar_chair_round_01": "Dairon Sanchez",
    "rubber_duck_toy": "Plat251",
    "painted_wooden_sofa": "Kirill Sannikov",
}
SURFACES = {
    "concrete_floor": "eye-candy.xyz",
    "worn_plaster_wall": "Dimitrios Savva",
    "rusty_metal_sheet": "Amal Kumar",
    "dirty_carpet": "Poly Haven",
    "large_grey_tiles": "Poly Haven",
}
API = "https://api.polyhaven.com"
LIMIT = 44_000_000

def get_json(url):
    req = urllib.request.Request(url, headers={"User-Agent":"Faceless2-licensed-real-PBR/0.27"})
    with urllib.request.urlopen(req, timeout=75) as response:
        return json.load(response)

def download(info, path):
    url = str(info["url"])
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or parsed.hostname != "dl.polyhaven.org":
        raise ValueError("Unapproved Poly Haven download host: " + url)
    expected = int(info["size"])
    if expected < 100 or expected > LIMIT:
        raise ValueError("Invalid publisher file size: " + path.name)
    # Never accept bytes by updating the expected digest after a failure.
    # The same immutable publisher record is checked on every fresh request.
    expected_md5 = str(info["md5"]).lower()
    if len(expected_md5) != 32 or any(c not in "0123456789abcdef" for c in expected_md5):
        raise ValueError("Invalid publisher MD5: " + path.name)
    last_error = ""
    for attempt in range(3):
        req = urllib.request.Request(url, headers={
            "User-Agent":"Faceless2-licensed-real-PBR/0.31",
            "Cache-Control":"no-cache", "Accept-Encoding":"identity"})
        try:
            with urllib.request.urlopen(req, timeout=100) as response:
                final = urllib.parse.urlparse(response.geturl())
                if final.scheme != "https" or final.hostname != "dl.polyhaven.org":
                    raise ValueError("Unapproved Poly Haven redirect host")
                data = response.read(LIMIT + 1)
                status = response.status
                content_type = response.headers.get("Content-Type", "unknown")
            actual_md5 = hashlib.md5(data).hexdigest()
            actual_sha256 = hashlib.sha256(data).hexdigest()
            valid = len(data) == expected and actual_md5 == expected_md5
            print("POLYHAVEN_DOWNLOAD", json.dumps({
                "file":path.name, "url":url, "attempt":attempt+1,
                "status":status, "content_type":content_type,
                "expected_bytes":expected, "actual_bytes":len(data),
                "expected_md5":expected_md5, "actual_md5":actual_md5,
                "actual_sha256":actual_sha256, "verified":valid}, sort_keys=True), flush=True)
            if valid: break
            last_error = "Publisher file size / MD5 mismatch: " + path.name
        except (urllib.error.URLError, TimeoutError, OSError) as error:
            # Do not print exception URLs or credentials; sources above are public.
            last_error = "Poly Haven transport failure: " + path.name + " (" + type(error).__name__ + ")"
            print("POLYHAVEN_RETRY", path.name, attempt+1, type(error).__name__, flush=True)
        if attempt < 2: time.sleep(attempt+1)
    else:
        raise ValueError(last_error)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    print("POLYHAVEN_VERIFIED", path.name, len(data))
    return data

def leaves(tree, keys=()):
    if isinstance(tree, dict) and all(k in tree for k in ("url","size","md5")):
        yield keys, tree
    elif isinstance(tree, dict):
        for key, value in tree.items():
            yield from leaves(value, keys + (str(key).lower(),))

def texture_entry(tree, channel):
    matches = []
    for keys, value in leaves(tree):
        if "1k" not in keys:
            continue
        first = keys[0].replace(" ","_")
        ok = (channel == "diffuse" and (first.startswith("diff") or first in ("albedo","basecolor"))
              or channel == "normal" and ("nor_gl" in first or "normal_gl" in first)
              or channel == "rough" and first.startswith("rough"))
        if not ok: continue
        ext = Path(urllib.parse.urlparse(value["url"]).path).suffix.lower()
        if ext in (".jpg",".jpeg",".png"):
            matches.append((0 if ext == ".jpg" else 1, value, ext))
    if not matches:
        raise ValueError("No 1k original PBR map " + channel + ": " + repr(list(tree)))
    matches.sort(key=lambda row:row[0])
    return matches[0][1], matches[0][2]

def build(output, credits, report):
    output.mkdir(parents=True, exist_ok=True)
    audit = {"models":{}, "surfaces":{}, "license":"CC0-1.0"}
    for name, author in MODELS.items():
        info = get_json(API+"/info/"+urllib.parse.quote(name))
        if int(info.get("type",-1)) != 2 or not info.get("authors"):
            raise ValueError("Missing real publisher model metadata: "+name)
        tree = get_json(API+"/files/"+urllib.parse.quote(name))
        versions = tree["gltf"]
        variant = "1k" if "1k" in versions else ("2k" if "2k" in versions else sorted(versions)[0])
        entry = versions[variant]["gltf"]
        incl = entry.get("include",{})
        if not isinstance(incl,dict): raise ValueError("Unexpected glTF include structure")
        with tempfile.TemporaryDirectory(prefix="f2-polyhaven-") as folder:
            temp = Path(folder)
            basename = Path(urllib.parse.urlparse(entry["url"]).path).name
            if not basename.endswith(".gltf"): raise ValueError("Expected publisher original glTF")
            primary = temp / basename
            download(entry, primary)
            for relative, resource in incl.items():
                filename = Path(relative)
                if filename.is_absolute() or ".." in filename.parts:
                    raise ValueError("Unsafe glTF dependency path")
                download(resource, temp/filename)
            parsed = json.loads(primary.read_text(encoding="utf8"))
            for part in parsed.get("buffers",[])+parsed.get("images",[]):
                uri = str(part.get("uri",""))
                if uri and not uri.startswith("data:") and not (temp/urllib.parse.unquote(uri)).is_file():
                    raise ValueError("Missing glTF texture/buffer: "+uri)
            destination = output/("scan_"+name.lower()+".glb")
            subprocess.run(["npx","--yes","@gltf-transform/cli@4.5.1",
                            "cp",str(primary),str(destination)],check=True)
        raw = destination.read_bytes()
        if raw[:4] != b"glTF" or len(raw) < 2048:
            raise ValueError("Not a real authored GLB: "+name)
        audit["models"][name] = {"author":author,"source":"https://polyhaven.com/a/"+name,
             "variant":variant,"output":destination.name,"size":len(raw),
             "sha256":hashlib.sha256(raw).hexdigest()}
        print("REAL_SCANNED_GLB_PASS",name,len(raw))
    for name, author in SURFACES.items():
        info = get_json(API+"/info/"+urllib.parse.quote(name))
        if int(info.get("type",-1)) != 1 or not info.get("authors"):
            raise ValueError("Missing PBR author/type metadata: "+name)
        tree = get_json(API+"/files/"+urllib.parse.quote(name))
        maps = {}
        for channel in ("diffuse","normal","rough"):
            record, ext = texture_entry(tree,channel)
            target = output/("pbr_"+name+"_"+channel+ext)
            raw = download(record,target)
            maps[channel] = {"file":target.name,"bytes":len(raw),"sha256":hashlib.sha256(raw).hexdigest()}
        audit["surfaces"][name] = {"author":author,"source":"https://polyhaven.com/a/"+name,"maps":maps}
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(json.dumps(audit,indent=2)+"\n",encoding="utf8")
    with credits.open("a",encoding="utf8") as f:
        f.write("\n## v0.27 real-world scan GLBs and physically based textures\n\n"
                "Publisher: Poly Haven; all items CC0 1.0 and permitted for commercial redistribution "
                "(https://creativecommons.org/publicdomain/zero/1.0/). Original human-authored "
                "model geometry and scanned texture maps are used. Upstream downloads are "
                "size/MD5 verified against the live publisher API; packaged bytes SHA-256 recorded.\n")
        for name, entry in audit["models"].items():
            f.write("- "+name+" by "+entry["author"]+": "+entry["source"]+
                    "; real GLB "+entry["output"]+" SHA-256 "+entry["sha256"]+".\n")
        for name, entry in audit["surfaces"].items():
            f.write("- "+name+" by "+entry["author"]+": "+entry["source"]+"; ")
            f.write("; ".join(k+" "+v["file"]+" SHA-256 "+v["sha256"] for k,v in entry["maps"].items())+".\n")
        f.write("Build report: real-backrooms-assets.json (all original and packaged checks).\n")
    print("REAL_BACKROOMS_CC0_ASSETS_PASS",len(audit["models"]),len(audit["surfaces"]))

if __name__ == "__main__":
    build(Path(sys.argv[1]),Path(sys.argv[2]),Path(sys.argv[3]))
