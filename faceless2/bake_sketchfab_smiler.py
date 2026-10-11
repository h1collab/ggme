"""Deterministically bake the licensed Sketchfab Smiler meshes to a 2D sprite.

Source: Speed12's authenticated Sketchfab CC BY 4.0 GLB, downloaded by
fetch_sketchfab_cast.py. The original six authored meshes, vertex positions,
teeth, eyes and pupils are rasterized orthographically. No AI/commercially
ambiguous replacement art, no screenshots, no GPU and no runtime model baking.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import trimesh
from PIL import Image, ImageDraw, ImageFilter

SIZE = (1024, 608)
PADDING = 77

def bake(source: Path, destination: Path) -> None:
    if not source.is_file() or source.read_bytes()[:4] != b"glTF":
        raise RuntimeError("Smiler sprite MUST come from authenticated Sketchfab GLB")
    scene = trimesh.load(str(source), force="scene", process=False)
    if len(scene.geometry) < 4:
        raise RuntimeError("Authorized Smiler has insufficient authored geometry")
    pieces = []
    all_points = []
    for node_name in scene.graph.nodes_geometry:
        transform, geometry_name = scene.graph[node_name]
        geometry = scene.geometry[geometry_name]
        points = trimesh.transform_points(geometry.vertices, transform)
        color_name = getattr(getattr(geometry.visual, "material", None), "name", "")
        pupil = color_name.lower() == "pupil"
        pieces.append((points, geometry.faces, pupil))
        all_points.append(points[:, [2, 1]])
    points2d = np.concatenate(all_points, axis=0)
    minimum = points2d.min(axis=0)
    maximum = points2d.max(axis=0)
    center = (minimum + maximum) / 2.0
    extent = maximum - minimum
    if min(extent) <= 0.001:
        raise RuntimeError("Smiler model has no usable visible face plane")
    width, height = SIZE
    scale = min((width - PADDING * 2) / extent[0], (height - PADDING * 2) / extent[1])
    triangles = []
    for vertices, faces, pupil in pieces:
        for index in faces:
            xyz = vertices[index]
            # The original facial surface lies in the YZ plane; project across
            # X. Preserve the original eyes/teeth silhouette, not a drawn face.
            polygon = [
                (round(width / 2 + (p[2] - center[0]) * scale),
                 round(height / 2 - (p[1] - center[1]) * scale))
                for p in xyz
            ]
            triangles.append((float(xyz[:, 0].mean()), polygon, pupil))
    art = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    painter = ImageDraw.Draw(art)
    for _depth, poly, pupil in sorted(triangles, key=lambda tri: tri[0]):
        painter.polygon(poly, fill=(3, 5, 7, 255) if pupil else (238, 244, 242, 255))
    mask = art.getchannel("A").filter(ImageFilter.GaussianBlur(13))
    mask = mask.point(lambda value: round(value * 0.28))
    halo = Image.new("RGBA", SIZE, (101, 179, 191, 0))
    halo.putalpha(mask)
    halo.alpha_composite(art)
    destination.parent.mkdir(parents=True, exist_ok=True)
    halo.save(destination, optimize=True)
    if destination.stat().st_size < 5000:
        raise RuntimeError("Baked Sketchfab texture appears empty")
    print("SKETCHFAB_SMILER_SPRITE_PASS",
          len(scene.geometry), "meshes", str(destination.stat().st_size), "bytes",
          hashlib.sha256(destination.read_bytes()).hexdigest())
    (destination.parent / (destination.stem + ".source.json")).write_text(
        json.dumps({
            "original": "https://sketchfab.com/3d-models/accurate-smiler-backrooms-blender-322-902975161a7047baa5cda8fb7b5a292e",
            "creator": "Speed12", "license": "CC BY 4.0",
            "transformation": "CPU orthographic texture bake of original Sketchfab glTF mesh",
            "glb_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
            "sprite_sha256": hashlib.sha256(destination.read_bytes()).hexdigest()
        }, indent=2) + "\n", encoding="utf-8")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("original", type=Path)
    parser.add_argument("png", type=Path)
    args = parser.parse_args()
    bake(args.original, args.png)
