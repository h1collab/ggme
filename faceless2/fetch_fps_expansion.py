"""Verified Quaternius CC0 GLB imports: original meshes, rigs and animations.
Manifest pins a fixed upstream Git revision, blob SHA-1, size and SHA-256.
Never accept a changed download by updating its expected hash at runtime.
"""
import hashlib
import json
from pathlib import Path
import sys
import urllib.request


def verify(raw, entry):
    obj = b'blob '+str(len(raw)).encode()+b'\0'+raw
    if len(raw) != entry['size'] or hashlib.sha1(obj).hexdigest() != entry['git_blob'] or hashlib.sha256(raw).hexdigest() != entry['sha256']:
        raise ValueError('Quaternius source mismatch: '+entry['file'])
    if raw[:4] != b'glTF' or int.from_bytes(raw[8:12], 'little') != len(raw):
        raise ValueError('Invalid original GLB: '+entry['file'])
    doc = json.loads(raw[20:20+int.from_bytes(raw[12:16], 'little')])
    if not doc.get('meshes') or any(b.get('uri') for b in doc.get('buffers', [])):
        raise ValueError('Source must contain embedded original meshes')
    if 'character' in entry['file'] and (not doc.get('skins') or not doc.get('animations')):
        raise ValueError('Character must preserve original skin and animations')


def main(folder):
    manifest = json.loads(Path(__file__).with_name('fps_expansion_assets.json').read_text())
    folder.mkdir(parents=True, exist_ok=True)
    for entry in manifest['assets']:
        path = folder/entry['file']
        if path.exists():
            raw = path.read_bytes()
        else:
            request = urllib.request.Request(manifest['root']+entry['path'], headers={'User-Agent':'Faceless2-CC0-Expansion'})
            with urllib.request.urlopen(request, timeout=90) as response:
                raw = response.read(4000000)
        verify(raw, entry)
        path.write_bytes(raw)
        print('FPS_EXPANSION_ORIGINAL_GLB_PASS', entry['file'], entry['sha256'])

if __name__ == '__main__': main(Path(sys.argv[1]))
