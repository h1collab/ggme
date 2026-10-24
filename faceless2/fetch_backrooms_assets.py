"""Fetch licensed vendor assets by pinned URL/hash; subset the Chinese font.

This downloads third-party art; it never synthesizes geometry or character art.
The converted HorrorGameMaker entity is committed separately as entity.glb.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import tempfile
import urllib.request

from fontTools import subset
from optimize_glb import optimize

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('output', type=Path)
args = parser.parse_args()
source = Path(__file__).resolve().parent
manifest = json.loads((source / 'backrooms_assets.json').read_text())
args.output.mkdir(parents=True, exist_ok=True)


def download(entry):
    request = urllib.request.Request(entry['url'], headers={'User-Agent': 'ZorixNightRelay/0.12 asset build'})
    with urllib.request.urlopen(request, timeout=90) as response:
        data = response.read()
    if hashlib.sha256(data).hexdigest() != entry['sha256']:
        raise RuntimeError('Asset hash mismatch: ' + entry.get('file', 'font'))
    return data


def fetch(entry):
    path = args.output / entry['file']
    # Downloads are verified before modifying bytes for mobile texture budgets.
    data = download(entry)
    path.write_bytes(data)
    report = optimize(path) if path.suffix == '.glb' else None
    print('Verified external asset:', entry['file'])
    return report


with ThreadPoolExecutor(max_workers=6) as pool:
    reports = list(pool.map(fetch, manifest['assets']))

with tempfile.TemporaryDirectory() as directory:
    font_source = Path(directory) / 'source.otf'
    font_source.write_bytes(download(manifest['font']))
    text = ''.join(path.read_text() for path in source.glob('backrooms*.gd'))
    text += ''.join(chr(code) for code in range(32, 127))
    options = subset.Options()
    font = subset.load_font(str(font_source), options)
    processor = subset.Subsetter(options=options)
    processor.populate(text=text)
    processor.subset(font)
    for record in font['name'].names:
        if record.nameID in (1, 4, 6, 16):
            family = 'ZorixStorySans' if record.nameID == 6 else 'Zorix Story Sans'
            record.string = family.encode(record.getEncoding())
    subset.save_font(font, str(args.output / 'story_font.otf'), options)

(args.output / 'model-budget.json').write_text(json.dumps([r for r in reports if r], indent=2))
print('External Backrooms assets: verified / models, recorded audio, photo textures, Chinese font')
