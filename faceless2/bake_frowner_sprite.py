"""Build a distinct Frowner 2D sprite from Speed12's licensed Smiler bake.

This is a CC BY 4.0 derivative, NOT the official Frowner image, and is never
labelled a sourced Frowner model. Reuses the human-authored Sketchfab mesh bake.
Eye regions remain real original art; its mouth is deformed into a frown.
"""
from __future__ import annotations
import hashlib
import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageEnhance


def bake(source: Path, target: Path) -> None:
    if not source.is_file():
        raise ValueError("Cannot create Frowner derivative without authentic Speed12 sprite")
    src = Image.open(source).convert("RGBA")
    if src.width != 1024 or src.height != 608:
        raise ValueError("Unexpected original Smiler geometry bake resolution")
    width, height = src.size
    top = 205
    # Preserve the original eye mesh pixels; transform ONLY the grin's lower half.
    result = Image.new("RGBA", src.size, (0, 0, 0, 0))
    mouth = Image.new("RGBA", src.size, (0, 0, 0, 0))
    for x in range(width):
        norm = min(1.0, abs(x - width * 0.5) / (width * 0.5))
        # Mouth ends droop; centre moves towards the eyes.
        dy = round(-155.0 * (1 - norm**1.65) + 145.0 * norm**1.65)
        column = src.crop((x, top, x + 1, height))
        mouth.paste(column, (x, top + dy), column)
    result.alpha_composite(mouth)
    result.alpha_composite(src.crop((0, 0, width, top)), (0, 0))
    # A different colder, sorrowful look; maintain inherited tooth/eye geometry.
    pixels = result.load()
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a:
                pixels[x, y] = (min(255, int(r*0.69)), min(255, int(g*0.85)), min(255, int(b*1.0)), a)
    # The original grin teeth alone still read as a smile after deformation.
    # Clear the inherited lower half and draw a single obvious downturned
    # expression, while preserving the original authored eye mesh geometry.
    # This remains explicitly a 2D derivative, not a newly modelled creature.
    clear = ImageDraw.Draw(result)
    clear.rectangle((225, 210, 805, 575), fill=(0, 0, 0, 0))
    d = ImageDraw.Draw(result)
    d.arc((274, 255, 760, 525), 184, 356, fill=(191, 214, 232, 244), width=27)
    # Downturned brows are 2D editor-drawn accents, not a fabricated 3D monster.
    d.arc((274, 109, 496, 197), 192, 354, fill=(137, 172, 208, 234), width=13)
    d.arc((535, 109, 757, 197), 188, 351, fill=(137, 172, 208, 234), width=13)
    if result.getbbox() is None:
        raise ValueError("Empty Frowner derivative")
    target.parent.mkdir(parents=True, exist_ok=True)
    target_png = target
    result.save(target_png)
    meta = {
        "creator_of_original": "Speed12", "license": "CC BY 4.0",
        "original_glb_source": "https://sketchfab.com/3d-models/accurate-smiler-backrooms-blender-322-902975161a7047baa5cda8fb7b5a292e",
        "derivative": "Frowner-inspired 2D deformation and recolour by Faceless 2 build script; not the canonical Frowner image",
        "source_png_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "output_png_sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
    }
    target.with_suffix(".source.json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf8")
    print("FROWNER_DERIVATIVE_PASS", meta["output_png_sha256"], "source", meta["source_png_sha256"])


if __name__ == "__main__":
    bake(Path(sys.argv[1]), Path(sys.argv[2]))
