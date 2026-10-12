"""Bake a sealed laboratory GLB from original verified Kenney CC0 GLB vertices.

Never use BoxMesh or synthesized render geometry: floors, walls, trims and roof
are assembled from Kenney meshes fetched/validated by fetch_wakeup_assets.py.
Merge repeated transformed meshes by module class to reduce draw calls and
close visual seams. Physical barriers stay cheap invisible Godot proxies.
"""
from __future__ import annotations
import hashlib
import json
import sys
from collections import defaultdict
from pathlib import Path
import numpy as np
import trimesh


def bake(vendor: Path, credits: Path, report: Path) -> None:
    components = {}
    for kind in ("floor_panel", "wall", "structure_panel", "wall_door"):
        path = vendor / ("wakeup_" + kind + ".glb")
        if not path.is_file() or path.read_bytes()[:4] != b"glTF":
            raise ValueError("No original verified Kenney GLB: " + str(path))
        source = trimesh.load(str(path), force="scene", process=False)
        bounds = source.bounds
        if bounds is None or min(bounds[1] - bounds[0]) <= 0.0001:
            raise ValueError("Invalid geometry bounds: " + kind)
        components[kind] = (source, bounds)

    batches = defaultdict(list)
    count = 0

    def piece(kind: str, group: str, xyz: tuple, dims: tuple):
        nonlocal count
        src, bounds = components[kind]
        size = np.maximum(bounds[1] - bounds[0], 0.0001)
        factors = np.array(dims, dtype=float) / size
        center = (bounds[0] + bounds[1]) * 0.5
        offset = np.array(xyz, dtype=float) - np.array([center[0], bounds[0][1], center[2]]) * factors
        matrix = np.eye(4)
        matrix[:3, :3] = np.diag(factors)
        matrix[:3, 3] = offset
        added = 0
        for name in src.graph.nodes_geometry:
            transform, geom_id = src.graph[name]
            original = src.geometry[geom_id].copy()
            if not isinstance(original, trimesh.Trimesh) or len(original.faces) == 0:
                continue
            original.apply_transform(matrix @ transform)
            batches[group].append(original)
            added += 1
        if added == 0:
            raise ValueError("Empty licensed prefab: " + kind)
        count += 1

    for x in (8.0, 9.5, 11.0, 12.5, 14.0):
        for z in (-0.5, -2.0, -3.5, -5.0, -6.5):
            piece("floor_panel", "Floor", (x, -0.075, z), (1.56, 0.18, 1.57))
    for z in (-0.5, -2.0, -3.5, -5.0, -6.5):
        piece("structure_panel", "Roof", (11.0, 3.09, z), (7.85, .24, 1.61))
        piece("wall", "Wall", (14.83, -0.02, z), (.27, 3.16, 1.60))
    # Leave exactly one entrance at x=7.15, centered z=-0.9; remaining wall closed.
    for z in (-3.5, -5.0, -6.5):
        piece("wall", "Wall", (7.17, -0.02, z), (.30, 3.16, 1.6))
    piece("wall_door", "Frame", (7.16, -0.02, -0.9), (.30, 3.15, 2.3))
    # Both cross-walls have small overlap so no end-of-room holes.
    for x in (8.0, 9.5, 11.0, 12.5, 14.0):
        piece("wall", "Wall", (x, -0.02, 0.38), (1.60, 3.16, .29))
        piece("wall", "Wall", (x, -0.02, -7.33), (1.60, 3.16, .29))

    output = trimesh.Scene()
    faces_total = 0
    for group, meshes in sorted(batches.items()):
        merged = trimesh.util.concatenate(meshes)
        if len(merged.faces) < 10:
            raise ValueError("Empty sealed shell module class: " + group)
        faces_total += len(merged.faces)
        # Preserve the geometric origin while standardising low-cost material.
        # Per-class PBR textures are assigned in Godot with double-sided culling.
        merged.visual = trimesh.visual.ColorVisuals(
            mesh=merged, vertex_colors=np.tile([210, 215, 215, 255], (len(merged.vertices), 1))
        )
        output.add_geometry(merged, geom_name="Kenney_CC0_Lab_" + group)
    outpath = vendor / "laboratory_shell_cc0.glb"
    outpath.write_bytes(output.export(file_type="glb"))
    data = outpath.read_bytes()
    if data[:4] != b"glTF" or len(data) < 2048:
        raise ValueError("Bad sealed GLB export")
    digest = hashlib.sha256(data).hexdigest()
    result = {
        "source": "Kenney Space Station Kit (CC0)",
        "catalog": "https://kenney.nl/assets/space-station-kit",
        "source_files": sorted(components),
        "license": "CC0-1.0",
        "assembled_modules": count, "merged_batches": len(batches),
        "triangles": faces_total, "glb_size": len(data), "glb_sha256": digest,
    }
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(json.dumps(result, indent=2) + "\n", encoding="utf8")
    with credits.open("a", encoding="utf8") as f:
        f.write("\n## v0.25 sealed laboratory shell\n\n"
                "New spatially enclosed laboratory GLB assembled only from original "
                "Kenney Space Station Kit GLB vertices, CC0-1.0, "
                "https://kenney.nl/assets/space-station-kit ; "
                "verified inputs by `fetch_wakeup_assets.py`, authored layout / "
                "batching in `bake_laboratory_glb.py`. "
                f"Package file `assets/vendor/laboratory_shell_cc0.glb`: SHA-256 `{digest}`, "
                f"{count} authored modules combined into {len(batches)} GLB meshes. "
                "This is modified licensed geometry, not procedural primitive models.\n")
    print("LABORATORY_SHELL_PASS", json.dumps(result))


if __name__ == "__main__":
    bake(Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3]))
