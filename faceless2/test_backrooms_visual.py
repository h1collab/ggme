"""Check actual captured GPU output for readable monitoring controls."""
import argparse
from pathlib import Path
from PIL import Image


def check_monitor(path):
    image = Image.open(path).convert('RGB')
    width, height = image.size
    assert abs(width / height - 16 / 9) < .02, 'Unexpected monitor aspect'
    controls = [(1260, 28, 290, 60)]
    controls += [(1090, 295 + i * 85, 455, 66) for i in range(2)]
    controls += [(1090, y, 455, 66) for y in (470, 555, 640)]
    controls += [(55 + i * 340, 716, 320, 72) for i in range(3)]
    controls += [(55, 811, 1000, 60)]
    for index, (x, y, w, h) in enumerate(controls):
        box = (round((x + 8) * width / 1600), round((y + 8) * height / 900),
               round((x + w - 8) * width / 1600), round((y + h - 8) * height / 900))
        # Exclude borders; the remaining bright pixels must come from text.
        visible = sum(r > 123 and g > 127 and b > 50
                      for r, g, b in image.crop(box).getdata())
        assert visible >= 45, f'{path.name}: unreadable control {index}'


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--directory', required=True)
    args = parser.parse_args()
    paths = [p for p in Path(args.directory).glob('*.png')
             if not p.name.startswith('android') and ('monitor' in p.name or 'camera' in p.name)]
    assert len(paths) == 9, f'Expected all nine feeds, got {len(paths)}'
    for path in paths:
        check_monitor(path)
    print('Backrooms rendered controls: PASS / 9 live feeds, 90 button regions')
