"""Fetch pinned original Poly Haven CC0 weapon detail maps; no hash bypass."""
import hashlib
import json
from pathlib import Path
import sys

from fetch_real_backrooms_assets import download, get_json

SOURCE = "metal_plate_02"
AUTHOR = "Rob Tuytel"
CHANNELS = {"diffuse":"Diffuse", "normal":"nor_gl", "rough":"Rough", "metal":"Metal"}
PINNED = {'diffuse': {'md5': '531b7e067dc537e0b3c7962175e04ffd',
             'sha256': '6e80877d0e9d5973d96298c6091df7ace906b0a6760afc4f3592e4855f3f1d4c',
             'size': 625917,
             'url': 'https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/metal_plate_02/metal_plate_02_diff_1k.jpg'},
 'metal': {'md5': '6ecfe9cdb7e0147c3dd7b49776d4a7d6',
           'sha256': 'fb1b120a2be5887dfeebed7a198a8151b292e963713d914b74ed7669434afb41',
           'size': 551170,
           'url': 'https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/metal_plate_02/metal_plate_02_metal_1k.jpg'},
 'normal': {'md5': 'ce8198004fd9409f592a7f024be0c01e',
            'sha256': '58736fbb8aa4fc6690cf8152b174db65caf22a766375b625fb0087e1bc955bc7',
            'size': 183264,
            'url': 'https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/metal_plate_02/metal_plate_02_nor_gl_1k.jpg'},
 'rough': {'md5': '1fa97d5031aa575656a316bfd404ca4d',
           'sha256': '73a6bd6393f6de7be42058584c2d382f2a3e9148ceabc2d02e748e2c860e74d1',
           'size': 911772,
           'url': 'https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/metal_plate_02/metal_plate_02_rough_1k.jpg'}}


def build(output, credits, report):
    info = get_json("https://api.polyhaven.com/info/"+SOURCE)
    if info.get("type") != 1 or AUTHOR not in info.get("authors", {}):
        raise ValueError("Official weapon surface author/type changed")
    tree = get_json("https://api.polyhaven.com/files/"+SOURCE)
    output.mkdir(parents=True, exist_ok=True)
    audit = {"source":"https://polyhaven.com/a/"+SOURCE,"author":AUTHOR,"license":"CC0-1.0","maps":{}}
    for channel, key in CHANNELS.items():
        pinned = PINNED[channel]
        record = tree[key]["1k"]["jpg"]
        for field in ("url","size","md5"):
            if record[field] != pinned[field]:
                raise ValueError("Publisher record changed for weapon map: "+channel+" / "+field)
        target = output/("pbr_weapon_metal_"+channel+".jpg")
        raw = download(record,target)
        digest = hashlib.sha256(raw).hexdigest()
        if digest != pinned["sha256"]:
            target.unlink()
            raise ValueError("Pinned weapon PBR SHA-256 mismatch: "+channel)
        audit["maps"][channel] = {"file":target.name,**pinned}
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(json.dumps(audit,indent=2)+"\n")
    with credits.open("a",encoding="utf8") as handle:
        handle.write("\n## FPS weapon surface detail maps\n\nPoly Haven Metal Plate 02 by Rob Tuytel (CC0-1.0), https://polyhaven.com/a/metal_plate_02. Original 1K maps remain unchanged. Publisher size/MD5 and pinned SHA-256 are all verified. Local-space shader projection supplies subtle surface detail on the original Kenney gun; original geometry and atlas are preserved.\n")
        for channel, record in audit["maps"].items():
            handle.write("- "+channel+": "+record["file"]+"; source "+record["url"]+"; SHA-256 "+record["sha256"]+".\n")
    print("FPS_PINNED_CC0_PBR_PASS",len(audit["maps"]))


if __name__ == "__main__":
    build(*(Path(value) for value in sys.argv[1:4]))
