"""Extract only the original Cesium Man arm triangles into an authentic skinned GLB.

Original GLB (Cesium, CC BY 4.0) remains the sole geometry source. This
script keeps the original mesh attributes, bone skin and walk animation and
replaces only the primitive's triangle index list. No synthetic mesh is made.
"""
import argparse
import json
import struct
from pathlib import Path


def unpack_accessor(gltf, bin_chunk, accessor_index):
    acc = gltf['accessors'][accessor_index]
    bv = gltf['bufferViews'][acc['bufferView']]
    kind = {5123: ('H', 2), 5125: ('I', 4), 5126: ('f', 4), 5121: ('B', 1)}[acc['componentType']]
    width = {'SCALAR': 1, 'VEC4': 4}[acc['type']]
    stride = bv.get('byteStride', kind[1] * width)
    offset = bv.get('byteOffset', 0) + acc.get('byteOffset', 0)
    return [struct.unpack_from('<' + kind[0] * width, bin_chunk, offset + i * stride)
            for i in range(acc['count'])]


def convert(source: Path, target: Path) -> tuple[int, int]:
    blob = source.read_bytes()
    assert blob[:4] == b'glTF' and struct.unpack_from('<I', blob, 4)[0] == 2
    length, label = struct.unpack_from('<I4s', blob, 12)
    assert label == b'JSON'
    gltf = json.loads(blob[20:20 + length])
    bin_offset = 20 + length
    bin_length, bin_label = struct.unpack_from('<I4s', blob, bin_offset)
    assert bin_label == b'BIN\0'
    chunk = bytearray(blob[bin_offset + 8:bin_offset + 8 + bin_length])
    primitive = gltf['meshes'][0]['primitives'][0]
    joints = unpack_accessor(gltf, chunk, primitive['attributes']['JOINTS_0'])
    weights = unpack_accessor(gltf, chunk, primitive['attributes']['WEIGHTS_0'])
    indices = [i[0] for i in unpack_accessor(gltf, chunk, primitive['indices'])]
    joint_names = [gltf['nodes'][n].get('name', '') for n in gltf['skins'][0]['joints']]
    arms = {idx for idx, name in enumerate(joint_names) if 'arm_joint_' in name}
    assert len(arms) >= 6, 'Expected authored arm joints'
    arm_weights = [sum(w for j, w in zip(js, ws) if j in arms) for js, ws in zip(joints, weights)]
    retained = []
    for t in range(0, len(indices), 3):
        triangle = indices[t:t + 3]
        if min(arm_weights[i] for i in triangle) > 0.52:
            retained.extend(triangle)
    assert len(retained) >= 300, f'Insufficient original arm triangles: {len(retained)}'
    while len(chunk) % 4:
        chunk.append(0)
    offset = len(chunk)
    chunk.extend(struct.pack('<' + 'H' * len(retained), *retained))
    while len(chunk) % 4:
        chunk.append(0)
    gltf['bufferViews'].append({'buffer': 0, 'byteOffset': offset, 'byteLength': len(retained)*2, 'target': 34963})
    gltf['accessors'].append({'bufferView': len(gltf['bufferViews']) - 1, 'componentType': 5123,
                              'count': len(retained), 'type': 'SCALAR',
                              'min': [min(retained)], 'max': [max(retained)]})
    primitive['indices'] = len(gltf['accessors']) - 1
    gltf['buffers'][0]['byteLength'] = len(chunk)
    gltf.setdefault('asset', {}).setdefault('extras', {})['attribution'] = 'Cesium Man (CC BY 4.0), arm triangles only; animation and skin retained'
    data = json.dumps(gltf, ensure_ascii=True, separators=(',', ':')).encode()
    data += b' ' * (-len(data) % 4)
    result = b'glTF' + struct.pack('<II', 2, 12 + 8 + len(data) + 8 + len(chunk))
    result += struct.pack('<I4s', len(data), b'JSON') + data
    result += struct.pack('<I4s', len(chunk), b'BIN\x00') + chunk
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(result)
    return len(retained) // 3, len(indices) // 3


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('source', type=Path)
    parser.add_argument('target', type=Path)
    args = parser.parse_args()
    kept, original = convert(args.source, args.target)
    print(f'Original skinned Cesium arm triangles: {kept} / {original}; viewmodel={args.target.stat().st_size} bytes')
