"""Open the original Kenney CC0 scope by removing its two opaque end caps.

The fixed-hash original stays untouched. This derivative removes exactly 12
authored faces; no vertices, normals, UVs, materials or replacement meshes are
generated. Scope tube/frame and original gun/magazine geometry are preserved.
"""
import hashlib
import json
from pathlib import Path
import struct

SOURCE_SHA256 = 'e1fd9bb8839cc60d26bd12d5093cadccda22943b29db6c5846f8e9ec66309868'


def bake(source: Path, output: Path) -> str:
    data = source.read_bytes()
    if len(data) != 82676 or hashlib.sha256(data).hexdigest() != SOURCE_SHA256:
        raise ValueError('Optic baker requires the exact licensed Kenney source')
    size = struct.unpack_from('<I', data, 12)[0]
    gltf = json.loads(data[20:20+size])
    raw = bytearray(data[28+size:])
    scope = next(n for n in gltf['nodes'] if n.get('name') == 'scope')
    primitive = gltf['meshes'][scope['mesh']]['primitives'][0]

    def read(accessor_id):
        a = gltf['accessors'][accessor_id]
        view = gltf['bufferViews'][a['bufferView']]
        width = {'SCALAR':1, 'VEC3':3}[a['type']]
        fmt = {5123:'H', 5126:'f'}[a['componentType']]
        row = struct.calcsize(fmt)*width
        start = view.get('byteOffset', 0)+a.get('byteOffset', 0)
        stride = view.get('byteStride', row)
        return [struct.unpack_from('<'+fmt*width, raw, start+i*stride)
                for i in range(a['count'])]

    positions = read(primitive['attributes']['POSITION'])
    indices = [item[0] for item in read(primitive['indices'])]
    kept, removed = [], []
    for i in range(0, len(indices), 3):
        triangle = indices[i:i+3]
        points = [positions[v] for v in triangle]
        planar = max(p[2] for p in points)-min(p[2] for p in points) < 1e-5
        end_cap = (planar and abs(abs(points[0][2])-.12) < 1e-5
                   and all(p[0]**2+(p[1]-.15)**2 < .0205**2 for p in points))
        (removed if end_cap else kept).extend(triangle)
    if len(indices) != 612 or len(removed) != 36 or len(kept) != 576:
        raise ValueError('Unexpected authored scope end-cap topology')
    while len(raw) % 4:
        raw.append(0)
    offset = len(raw)
    raw.extend(struct.pack('<'+'H'*len(kept), *kept))
    gltf['bufferViews'].append({'buffer':0, 'byteOffset':offset,
                              'byteLength':len(kept)*2, 'target':34963})
    gltf['accessors'].append({'bufferView':len(gltf['bufferViews'])-1,
                            'componentType':5123, 'count':len(kept),
                            'type':'SCALAR', 'min':[min(kept)], 'max':[max(kept)]})
    primitive['indices'] = len(gltf['accessors'])-1
    gltf['buffers'][0]['byteLength'] = len(raw)
    gltf['asset'].setdefault('extras', {})['attribution'] = (
        'Kenney Blaster Kit, CC0 1.0; original scope minus 12 opaque cap faces; '
        'source SHA-256 '+SOURCE_SHA256)
    text = json.dumps(gltf, separators=(',', ':')).encode()
    text += b' '*(-len(text) % 4)
    result = (b'glTF'+struct.pack('<II',2,28+len(text)+len(raw))
              +struct.pack('<I4s',len(text),b'JSON')+text
              +struct.pack('<I4s',len(raw),b'BIN\0')+raw)
    output.write_bytes(result)
    digest = hashlib.sha256(result).hexdigest()
    print('FPS_AUTHORED_OPEN_OPTIC_PASS cap_faces_removed=12 scope_faces=192', digest)
    return digest


if __name__ == '__main__':
    import sys
    bake(Path(sys.argv[1]), Path(sys.argv[2]))
