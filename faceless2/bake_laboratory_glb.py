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
    corridor_batches = defaultdict(list)
    wing_batches = defaultdict(list)
    count = 0

    def piece(kind: str, group: str, xyz: tuple, dims: tuple, into=None):
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
            (batches if into is None else into)[group].append(original)
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
        # Actual powered observation door at the far end of the experiment.
        if x != 11.0:
            piece("wall", "Wall", (x, -0.02, -7.33), (1.60, 3.16, .29))
    piece("wall_door", "Frame", (11.0, -0.02, -7.33), (2.35, 3.16, .29))
    lab_count = count

    # Complete corridor shell: still ONLY transformed original Kenney mesh faces.
    # Previous GDScript instantiated ~80 duplicate GLB scene graphs at startup.
    for x in (-3.0, -1.5, 0.0, 1.5, 3.0):
        for z in (3.0, 1.5, 0.0, -1.5, -3.0, -4.5, -6.0, -7.5, -9.0):
            piece("floor_panel", "Corridor_Floor", (x, -0.075, z), (1.51, .18, 1.51), corridor_batches)
    for z in (3.0, 1.5, 0.0, -1.5, -3.0, -4.5, -6.0, -7.5, -9.0):
        piece("wall", "Corridor_Walls", (-3.8, -0.02, z), (.22, 3.16, 1.51), corridor_batches)
        if z not in (0.0, -1.5):
            piece("wall", "Corridor_Walls", (3.8, -0.02, z), (.22, 3.16, 1.51), corridor_batches)
        piece("structure_panel", "Corridor_Roof", (0, 3.09, z), (7.5, .18, 1.51), corridor_batches)
    for x in (-3.0, -1.5, 0.0, 1.5, 3.0):
        piece("wall", "Corridor_End", (x, -0.02, -10.0), (1.51, 3.16, .3), corridor_batches)
    corridor_count = count - lab_count

    # This wing exists as a separate GLB and is NEVER instantiated before the
    # player finishes the live breaker puzzle. Main room stays opaque and sealed.
    for z in (-8.2, -9.7, -11.2):
        for x in (9.5, 11.0, 12.5):
            piece("floor_panel", "Wing_Floor", (x, -0.075, z), (1.55, .18, 1.55), wing_batches)
        piece("structure_panel", "Wing_Roof", (11.0, 3.09, z), (4.8, .22, 1.55), wing_batches)
        piece("wall", "Wing_Walls", (8.0, -0.02, z), (.27, 3.16, 1.55), wing_batches)
        piece("wall", "Wing_Walls", (14.0, -0.02, z), (.27, 3.16, 1.55), wing_batches)
    for x in (9.5, 11.0, 12.5):
        piece("wall", "Wing_End", (x, -0.02, -12.0), (1.55, 3.16, .3), wing_batches)
    wing_count = count - lab_count - corridor_count

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

    def uv_wrap_triangles(mesh):
        """Generate REAL UVs on source Kenney geometry for sampled PBR scans.

        Prior v0.28 vertex-color merges stripped TEXCOORD_0, so applying
        PBR in GDScript could sample one texel over whole walls/floor.
        Duplicate only per-face vertices, project meter-scaled UV based on
        the dominant physical face normal, and preserve every source face.
        """
        mesh.unmerge_vertices()
        indices = mesh.faces.reshape(-1)
        xyz = np.asarray(mesh.vertices[indices], dtype=np.float64)
        axes = np.repeat(np.abs(mesh.face_normals).argmax(axis=1), 3)
        uv = np.empty((len(mesh.vertices), 2), dtype=np.float64)
        uv[indices, 0] = np.where(axes == 0, xyz[:, 2], xyz[:, 0]) * 0.63
        uv[indices, 1] = np.where(axes == 1, xyz[:, 2], xyz[:, 1]) * 0.63
        mesh.visual = trimesh.visual.TextureVisuals(uv=uv)
        if mesh.visual.uv is None or len(mesh.visual.uv) != len(mesh.vertices):
            raise ValueError("Failed to author wall/floor PBR UV on Kenney source geometry")
        return mesh

    def export_batch(collection, filename):
        source = trimesh.Scene()
        for group, meshes in sorted(collection.items()):
            merged = trimesh.util.concatenate(meshes)
            if len(merged.faces) < 10:
                raise ValueError("Missing sourced triangles: " + group)
            if filename == "facility_corridor_cc0.glb":
                merged = uv_wrap_triangles(merged)
            else:
                merged.visual = trimesh.visual.ColorVisuals(
                    mesh=merged, vertex_colors=np.tile([210, 215, 215, 255], (len(merged.vertices), 1)))
            source.add_geometry(merged, geom_name="Kenney_CC0_" + group)
        path = vendor / filename
        path.write_bytes(source.export(file_type="glb"))
        if path.read_bytes()[:4] != b"glTF":
            raise ValueError("Invalid GLB: " + filename)
        if filename == "facility_corridor_cc0.glb":
            import struct
            raw = path.read_bytes()
            json_len = struct.unpack_from("<I", raw, 12)[0]
            gltf = json.loads(raw[20:20+json_len])
            for mesh_info in gltf["meshes"]:
                for primitive in mesh_info["primitives"]:
                    if "TEXCOORD_0" not in primitive["attributes"]:
                        raise ValueError("Authentic PBR atlas failed: GLB missing TEXCOORD_0")
            print("FACILITY_REAL_PBR_UV_PASS", len(gltf["meshes"]))
        return {"sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                "bytes": path.stat().st_size, "meshes": len(collection)}

    corridor = export_batch(corridor_batches, "facility_corridor_cc0.glb")
    wing = export_batch(wing_batches, "observation_wing_cc0.glb")
    result = {
        "source": "Kenney Space Station Kit (CC0)",
        "catalog": "https://kenney.nl/assets/space-station-kit",
        "source_files": sorted(components),
        "license": "CC0-1.0",
        "assembled_modules": lab_count, "merged_batches": len(batches),
        "corridor_modules": corridor_count, "corridor": corridor,
        "corridor_uv": "tri-planar-axis per-face metric UV0, 0.63 repeats/meter",
        "observation_modules": wing_count, "observation": wing,
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
                f"{lab_count} authored modules combined into {len(batches)} GLB meshes. "
                "This is modified licensed geometry, not procedural primitive models.\n"
                f"v0.26 corridor combined {corridor_count} original GLB modules into {corridor['meshes']} meshes; "
                f"`facility_corridor_cc0.glb` SHA-256 `{corridor['sha256']}`. "
                f"New on-demand observation wing combines {wing_count} Kenney source modules "
                f"into {wing['meshes']} meshes; `observation_wing_cc0.glb` SHA-256 `{wing['sha256']}`. "
                "The observation wing is instantiated only after restoring real breaker power; "
                "all models remain Kenney CC0 authored geometry, not generated primitives.\n")
    print("LABORATORY_SHELL_PASS", json.dumps(result))


if __name__ == "__main__":
    bake(Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3]))
