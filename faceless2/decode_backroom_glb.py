"""Reproducibly decode the preserved licensed huuxloc source GLB.

Build-only DracoPy 1.5.0 (Google Draco wrapper, Apache-2.0). Keep original
nodes, materials, textures, normals, UVs and decoded triangles. No remeshing.
The former npm CLI fails on this exact source under the current CI runtime.
"""
import hashlib
import json
import struct
import sys
from pathlib import Path
import DracoPy
import numpy as np

SOURCE_SHA256 = "948d80d419152b82cdedd03ce92cace39fbcd69d6801330cd3021995456c984c"

def decode(source: Path, output: Path) -> None:
    data = source.read_bytes()
    if hashlib.sha256(data).hexdigest() != SOURCE_SHA256:
        raise ValueError("Licensed huuxloc source SHA-256 mismatch")
    length = struct.unpack_from("<I",data,12)[0]
    model = json.loads(data[20:20+length])
    raw = bytearray(data[28+length:])
    views, accessors = model["bufferViews"],model["accessors"]
    def append(values, kind, component, target):
        array = np.asarray(values,dtype="<f4" if component == 5126 else "<u4")
        while len(raw)%4: raw.append(0)
        offset = len(raw)
        payload = array.tobytes()
        raw.extend(payload)
        views.append({"buffer":0,"byteOffset":offset,"byteLength":len(payload),"target":target})
        accessor = {"bufferView":len(views)-1,"componentType":component,"count":len(array),"type":kind}
        if kind == "VEC3":
            accessor.update(min=array.min(axis=0).tolist(),max=array.max(axis=0).tolist())
        accessors.append(accessor)
        return len(accessors)-1
    triangles = 0
    for mesh in model["meshes"]:
        for primitive in mesh["primitives"]:
            extension = primitive["extensions"].pop("KHR_draco_mesh_compression")
            view = views[extension["bufferView"]]
            start = view.get("byteOffset",0)
            decoded = DracoPy.decode(bytes(raw[start:start+view["byteLength"]]))
            if set(extension["attributes"]) != {"POSITION","NORMAL","TEXCOORD_0"}:
                raise ValueError("Unsupported source attribute inventory")
            for semantic,values,kind in [("POSITION",decoded.points,"VEC3"),("NORMAL",decoded.normals,"VEC3"),("TEXCOORD_0",decoded.tex_coord,"VEC2")]:
                if len(values) != accessors[primitive["attributes"][semantic]]["count"] or not np.isfinite(values).all():
                    raise ValueError("Decoded source attribute count/finiteness mismatch")
                primitive["attributes"][semantic] = append(values,kind,5126,34962)
            indices = decoded.faces.reshape(-1)
            if len(indices) != accessors[primitive["indices"]]["count"] or int(indices.max()) >= len(decoded.points):
                raise ValueError("Decoded source index inventory mismatch")
            primitive["indices"] = append(indices,"SCALAR",5125,34963)
            triangles += len(decoded.faces)
            if not primitive["extensions"]: primitive.pop("extensions")
    if triangles != 3912 or len(model["meshes"]) != 26:
        raise ValueError("Licensed source mesh/triangle inventory differs")
    for key in ("extensionsUsed","extensionsRequired"):
        if key in model:
            model[key] = [name for name in model[key] if name != "KHR_draco_mesh_compression"]
            if not model[key]: model.pop(key)
    while len(raw)%4: raw.append(0)
    model["buffers"][0]["byteLength"] = len(raw)
    js = json.dumps(model,separators=(",",":"),ensure_ascii=True).encode()
    js += b" "*(-len(js)%4)
    result = b"glTF"+struct.pack("<II",2,28+len(js)+len(raw))+struct.pack("<I4s",len(js),b"JSON")+js+struct.pack("<I4s",len(raw),b"BIN\0")+raw
    if hashlib.sha256(result).hexdigest() != "99d5f83a419919a51f5f692095dae0f80f432b0376a90c2d595e64a28ddca84c":
        raise ValueError("Deterministic Draco decode SHA-256 differs")
    output.write_bytes(result)
    print("LICENSED_DRACO_DECODE_PASS meshes=26 triangles=3912",hashlib.sha256(result).hexdigest())

if __name__ == "__main__": decode(Path(sys.argv[1]),Path(sys.argv[2]))
