"""Build-time provenance and deformation-stream checks on real licensed GLB.

Run after fetch_fps_assets.py with --source pointing at its untouched WRAD.
This checks mesh data; gameplay and rendering require separate Godot QA.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import tempfile

from bake_fps_grip_hands import bake
from fetch_fps_assets import verify_wrad_arms
from refine_fps_arms import refine


def unpack(path):
    data = path.read_bytes()
    assert data[:4] == b'glTF' and len(data) == struct.unpack_from('<I', data, 8)[0]
    size = struct.unpack_from('<I', data, 12)[0]
    g = json.loads(data[20:20+size])
    raw = data[28+size:]
    def read(index):
        a = g['accessors'][index]; view = g['bufferViews'][a['bufferView']]
        width = {'SCALAR':1, 'VEC2':2, 'VEC3':3, 'VEC4':4}[a['type']]
        fmt, count = {5121:('B',1),5123:('H',2),5125:('I',4),5126:('f',4)}[a['componentType']]
        start = view.get('byteOffset',0)+a.get('byteOffset',0)
        return [struct.unpack_from('<'+fmt*width,raw,start+i*view.get('byteStride',width*count)) for i in range(a['count'])]
    return g, raw, read


def main(source):
    original = source.read_bytes()
    verify_wrad_arms(original)
    reports = []
    with tempfile.TemporaryDirectory(prefix='wrad-refinement-') as temp:
        for side in ('r','l'):
            a, b = Path(temp)/'a.glb', Path(temp)/'b.glb'
            assert bake(source,a,side) == (589,1196)
            subset = a.read_bytes()
            before, raw, read_before = unpack(a)
            report = refine(a)
            b.write_bytes(subset)
            assert refine(b) == report and a.read_bytes() == b.read_bytes(), 'not deterministic'
            after, refined_raw, read = unpack(a)
            assert refined_raw[:len(raw)] == raw, 'original streams or inverse binds changed'
            for key in ('skins','nodes','scenes','materials','images','textures','samplers'):
                assert after.get(key) == before.get(key), key
            attrs = after['meshes'][0]['primitives'][0]['attributes']
            old = before['meshes'][0]['primitives'][0]['attributes']
            assert report['derived_triangles'] == 9424 and report['vertices'] == 5222
            assert report['source_subset_sha256'] == hashlib.sha256(subset).hexdigest()
            assert read(attrs['TEXCOORD_0'])[:len(read_before(old['TEXCOORD_0']))] == read_before(old['TEXCOORD_0'])
            points, normals = read(attrs['POSITION']),read(attrs['NORMAL'])
            assert any(points[i] != p for i,p in enumerate(read_before(old['POSITION']))), 'index-only subdivision'
            assert all(math.isfinite(v) for row in points+normals for v in row)
            assert all(abs(sum(v*v for v in normal)-1) < 1e-5 for normal in normals)
            assert all(abs(sum(row)-1) < 1e-5 and min(row)>=0 for row in read(attrs['WEIGHTS_0']))
            assert all(max(row)<len(after['skins'][0]['joints']) for row in read(attrs['JOINTS_0']))
            assert report['max_discarded_skin_weight'] < .12
            report['side'] = side; reports.append(report)
        invalid = Path(temp)/'invalid.glb'; invalid.write_bytes(original[:-1]+b'x')
        try: refine(invalid)
        except ValueError: pass
        else: raise AssertionError('Unverified source accepted')
    assert source.read_bytes() == original, 'source was modified'
    print('FPS_WRAD_REFINEMENT_PROVENANCE_PASS',json.dumps(reports,sort_keys=True))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--source',type=Path,required=True)
    main(parser.parse_args().source)
