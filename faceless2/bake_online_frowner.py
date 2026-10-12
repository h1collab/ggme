"""Recolor the *actual internet-sourced* CC BY 4.0 Twitter Twemoji Frowning Face.

Pinned upstream graphic: https://github.com/twitter/twemoji/blob/v14.0.2/assets/svg/2639.svg
License: https://github.com/twitter/twemoji/blob/v14.0.2/LICENSE-GRAPHICS
This is a Frowner-*inspired* licensed illustration, not wiki's copyrighted
canonical Frowner image. Source SVG is preserved byte-for-byte in git.
"""
import hashlib
import io
import json
import sys
from pathlib import Path
from PIL import Image, ImageChops, ImageFilter, ImageEnhance
import cairosvg

def render(source: Path, target: Path, credits: Path):
    data=source.read_bytes()
    if b'<svg' not in data or b'#664500' not in data or b'#FFCC4D' not in data:
        raise ValueError("Pinned source is not original Twemoji 2639.svg")
    png=cairosvg.svg2png(bytestring=data, output_width=768,output_height=768)
    raw=Image.open(io.BytesIO(png)).convert("RGBA")
    import numpy as np
    arr=np.asarray(raw).copy()
    # Use original author-drawn eye and frown shapes, rather than synthesising
    # other people’s character art. Remove only the yellow emoji background.
    dark=(arr[:,:,0]<185)&(arr[:,:,1]<155)&(arr[:,:,2]<100)&(arr[:,:,3]>40)
    alpha=Image.fromarray((dark*255).astype("uint8"),"L")
    alpha=alpha.filter(ImageFilter.GaussianBlur(0.6))
    glow=alpha.filter(ImageFilter.GaussianBlur(9))
    base=Image.new("RGBA",raw.size,(84,161,217,0))
    base.putalpha(glow.point(lambda x:int(x*.70)))
    eyes=Image.new("RGBA",raw.size,(229,243,255,0))
    eyes.putalpha(alpha)
    base.alpha_composite(eyes)
    if not base.getbbox(): raise ValueError("Licensed frown silhouette is blank")
    target.parent.mkdir(parents=True,exist_ok=True)
    base.save(target)
    src_hash=hashlib.sha256(data).hexdigest()
    out_hash=hashlib.sha256(target.read_bytes()).hexdigest()
    record={"original_author":"Twitter / Twemoji contributors",
        "original_file":"https://github.com/twitter/twemoji/blob/v14.0.2/assets/svg/2639.svg",
        "original_license":"CC BY 4.0",
        "license_url":"https://creativecommons.org/licenses/by/4.0/",
        "upstream_version":"v14.0.2",
        "source_sha256":src_hash,"derivative_png_sha256":out_hash,
        "modifications":"Rendered original authored SVG to PNG; removed yellow fill; applied cold glow to author-drawn facial expression.",
        "authenticity":"Frowner-inspired reinterpretation of online graphic, not official Backrooms Wiki Frowner art"}
    target.with_suffix(".source.json").write_text(json.dumps(record,indent=2)+"\n",encoding="utf8")
    with credits.open("a",encoding="utf8") as f:
        f.write("\n## v0.28 online Frowner-inspired sprite (NOT official Wiki image)\n\n"
                "Original internet illustration: **Frowning Face (U+2639)**, Twitter Twemoji contributors, "
                "[pinned v14.0.2 source](https://github.com/twitter/twemoji/blob/v14.0.2/assets/svg/2639.svg), "
                "**CC BY 4.0**, commercial redistribution and adaptation allowed with attribution: "
                "https://creativecommons.org/licenses/by/4.0/. "
                "Adaptation: isolate the author's eye/frown shapes, recolor to cold-white and soften into transparent billboard. "
                "Not an official Backrooms Frowner image. "
                f"Original SVG SHA-256 `{src_hash}`; distributed PNG SHA-256 `{out_hash}`. "
                "The original Twemoji SVG is preserved unchanged at `faceless2/assets/third_party/twemoji_2639.svg`.\n")
    print("FROWNER_ONLINE_LICENSED_IMAGE_PASS",src_hash,out_hash)

if __name__=="__main__":
    render(Path(sys.argv[1]),Path(sys.argv[2]),Path(sys.argv[3]))
