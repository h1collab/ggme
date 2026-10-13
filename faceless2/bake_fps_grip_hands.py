"""Bake ONLY authored WRAD CC0 wrist/hand/finger triangles out of the
fixed-hash original skinned GLB. Preserve geometry, UV, normals, original
material, full skeleton and bind data; discard disconnected upper-arm triangles.
The new GLB is a LICENSED SUBSET, never synthesized visible geometry.
"""
import json
import struct
from pathlib import Path

def bake(source: Path, output: Path) -> tuple[int, int]:
    data = source.read_bytes()
    assert data[:4] == b"glTF" and struct.unpack_from("<I",data,4)[0] == 2
    jl, typ = struct.unpack_from("<I4s",data,12)
    assert typ == b"JSON"
    g = json.loads(data[20:20+jl])
    base = 20 + jl
    bl, typ = struct.unpack_from("<I4s",data,base)
    assert typ == b"BIN\0"
    raw = bytearray(data[base+8:base+8+bl])
    prim = g["meshes"][0]["primitives"][0]
    acc = g["accessors"]
    bvs = g["bufferViews"]
    def item(accessor_id: int, index: int):
        a = acc[accessor_id]
        v = bvs[a["bufferView"]]
        width = {"SCALAR":1,"VEC4":4}[a["type"]]
        fmt,size = {5121:("B",1),5123:("H",2),5125:("I",4),5126:("f",4)}[a["componentType"]]
        off = v.get("byteOffset",0) + a.get("byteOffset",0) + index*v.get("byteStride",width*size)
        return struct.unpack_from("<"+fmt*width,raw,off)
    ia = prim["indices"]
    all_indices = [item(ia,i)[0] for i in range(acc[ia]["count"])]
    joints = g["skins"][0]["joints"]
    names = [g["nodes"][i].get("name","") for i in joints]
    def hand_weight(vertex: int) -> float:
        js = item(prim["attributes"]["JOINTS_0"],vertex)
        ws = item(prim["attributes"]["WEIGHTS_0"],vertex)
        return sum(w for j,w in zip(js,ws)
                   if names[j].startswith("finger_") or names[j].startswith("wrist.")
                   or names[j].startswith("socket."))
    weight = [hand_weight(i) for i in range(acc[prim["attributes"]["POSITION"]]["count"])]
    kept = []
    for t in range(0,len(all_indices),3):
        triangle = all_indices[t:t+3]
        if min(weight[v] for v in triangle) > 0.52:
            kept.extend(triangle)
    if len(kept) < 2000 or len(kept) >= len(all_indices):
        raise ValueError("WRAD source unexpected grip triangle count: %d" % (len(kept)//3))
    while len(raw)%4: raw.append(0)
    off = len(raw)
    fmt = "H" if max(kept)<65536 else "I"
    comp = 5123 if fmt=="H" else 5125
    raw.extend(struct.pack("<"+fmt*len(kept),*kept))
    while len(raw)%4: raw.append(0)
    g["bufferViews"].append({"buffer":0,"byteOffset":off,"byteLength":len(kept)*struct.calcsize(fmt),"target":34963})
    g["accessors"].append({"bufferView":len(g["bufferViews"])-1,"componentType":comp,
                           "count":len(kept),"type":"SCALAR","min":[min(kept)],"max":[max(kept)]})
    prim["indices"] = len(g["accessors"])-1
    g["buffers"][0]["byteLength"] = len(raw)
    g.setdefault("asset",{}).setdefault("extras",{})["attribution"] = (
        "WRAD ARMS, wriks, CC0 1.0; subset of original hand/wrist triangles only, original rig/skin/UV")
    js = json.dumps(g,ensure_ascii=True,separators=(",",":")).encode()
    js += b" "*(-len(js)%4)
    target = (b"glTF" + struct.pack("<II",2,12+8+len(js)+8+len(raw))
              + struct.pack("<I4s",len(js),b"JSON") + js
              + struct.pack("<I4s",len(raw),b"BIN\x00") + raw)
    output.write_bytes(target)
    return len(kept)//3,len(all_indices)//3

if __name__ == "__main__":
    import sys,hashlib
    src,dst = Path(sys.argv[1]),Path(sys.argv[2])
    a,b = bake(src,dst)
    print("FPS_WRAD_CC0_GRIP_SUBSET",a,b,hashlib.sha256(dst.read_bytes()).hexdigest())
