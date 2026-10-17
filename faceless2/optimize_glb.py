#!/usr/bin/env python3
"""Repack embedded GLBs with mobile texture budgets, preserving rigs and geometry.

No quantization, decimation or lossy mesh codec: Godot can import the result with
its normal glTF loader. Buffer-view indices and accessor data remain unchanged.
"""
import argparse
import hashlib
import io
import json
import struct
from pathlib import Path

from PIL import Image

HERO = {"fp_hands.glb", "pistol.glb", "rifle.glb", "faceless_entity.glb"}
SMALL = {"evidence_case.glb", "ammo_box.glb", "medkit.glb", "power_relay.glb", "security_terminal.glb"}


def read_glb(data):
    magic, version, length = struct.unpack_from("<4sII", data)
    if magic != b"glTF" or version != 2 or length != len(data):
        raise ValueError("Invalid GLB 2 header")
    chunks, offset = {}, 12
    while offset < length:
        size, kind = struct.unpack_from("<II", data, offset)
        offset += 8
        if offset + size > length or size % 4:
            raise ValueError("Invalid GLB chunk")
        chunks[kind] = data[offset:offset + size]
        offset += size
    if set(chunks) != {0x4E4F534A, 0x004E4942}:
        raise ValueError("Expected JSON and BIN chunks only")
    document = json.loads(chunks[0x4E4F534A])
    if len(document.get("buffers", [])) != 1 or "uri" in document["buffers"][0]:
        raise ValueError("Expected one embedded buffer")
    return document, chunks[0x004E4942]


def write_glb(document, binary):
    document["buffers"][0]["byteLength"] = len(binary)
    body = json.dumps(document, separators=(",", ":"), ensure_ascii=False).encode()
    body += b" " * (-len(body) % 4)
    binary += b"\0" * (-len(binary) % 4)
    length = 12 + 8 + len(body) + 8 + len(binary)
    return (struct.pack("<4sII", b"glTF", 2, length)
            + struct.pack("<II", len(body), 0x4E4F534A) + body
            + struct.pack("<II", len(binary), 0x004E4942) + binary)


def optimize(path):
    original = path.read_bytes()
    doc, binary = read_glb(original)
    limit = 2048 if path.name in HERO else (512 if path.name in SMALL else 1024)
    replacements, images = {}, []
    views = doc.get("bufferViews", [])
    for image in doc.get("images", []):
        if "bufferView" not in image or image.get("mimeType") not in ("image/png", "image/jpeg"):
            continue
        index = image["bufferView"]
        view = views[index]
        start = view.get("byteOffset", 0)
        encoded = binary[start:start + view["byteLength"]]
        with Image.open(io.BytesIO(encoded)) as source:
            before = source.size
            if max(before) > limit:
                source.thumbnail((limit, limit), Image.Resampling.LANCZOS)
                output = io.BytesIO()
                # PNG keeps alpha-tested foliage and packed PBR channels lossless.
                if image["mimeType"] == "image/png":
                    source.save(output, "PNG", optimize=True)
                else:
                    source.convert("RGB").save(output, "JPEG", quality=92, subsampling=0, optimize=True)
                replacements[index] = output.getvalue()
            images.append({"name": image.get("name", str(index)), "before": before, "after": source.size})
    packed, shared = bytearray(), {}
    for index, view in enumerate(views):
        if view.get("buffer", 0) != 0:
            raise ValueError("External buffer view")
        start, size = view.get("byteOffset", 0), view["byteLength"]
        if start < 0 or start + size > len(binary):
            raise ValueError("Buffer view out of bounds")
        data = replacements.get(index, binary[start:start + size])
        key = hashlib.sha256(data).digest()
        if key not in shared:
            packed.extend(b"\0" * (-len(packed) % 4))
            shared[key] = len(packed)
            packed.extend(data)
        view["byteOffset"], view["byteLength"] = shared[key], len(data)
    result = write_glb(doc, bytes(packed))
    # Re-parse the produced container before replacing the source atomically.
    read_glb(result)
    temporary = path.with_suffix(".glb.tmp")
    temporary.write_bytes(result)
    temporary.replace(path)
    rgba = lambda size: size[0] * size[1] * 4 * 4 // 3
    return {"asset": path.name, "texture_limit": limit, "bytes_before": len(original),
            "bytes_after": len(result), "images": images,
            "estimated_rgba_mips_before": sum(rgba(x["before"]) for x in images),
            "estimated_rgba_mips_after": sum(rgba(x["after"]) for x in images),
            "mesh_count": len(doc.get("meshes", [])), "skin_count": len(doc.get("skins", [])),
            "animation_count": len(doc.get("animations", []))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    results = [optimize(p) for p in sorted(args.directory.glob("*.glb"))]
    if not results:
        raise SystemExit("No GLBs found")
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps({"assets": results}, indent=2), encoding="utf-8")
    before = sum(r["bytes_before"] for r in results)
    after = sum(r["bytes_after"] for r in results)
    print(f"GLB optimization: {len(results)} assets, {before:,} -> {after:,} bytes ({(1-after/before)*100:.1f}% smaller)")


if __name__ == "__main__":
    main()
