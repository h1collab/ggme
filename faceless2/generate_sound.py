"""Reproducible synthesized Foley (NOT speech or device TTS).

Small band-limited mono WAV files are generated at build time. Sample playback
has almost no runtime CPU cost and needs no network access on the phone.
"""
import argparse
import math
import random
import struct
import wave
from pathlib import Path

RATE = 24000


def render(name: str, duration: float, seed: int):
    rng = random.Random(seed)
    total = round(RATE * duration)
    smooth = 0.0
    samples = []
    for i in range(total):
        t = i / RATE
        white = rng.uniform(-1, 1)
        smooth = smooth * 0.79 + white * 0.21
        if name == 'splash':
            envelope = math.exp(-t * 12.0)
            splash = (smooth * .70 + math.sin(2 * math.pi * (115 - 45 * t) * t) * .25) * envelope
            sample = splash + math.sin(2 * math.pi * 720 * t) * math.exp(-t*27) * .035
        elif name == 'elevator_door':
            fade = min(1.0, t * 7, max(0.0, (duration-t) * 8))
            sample = (0.28*math.sin(2*math.pi*(77 + 15 * t) * t) + 0.18*smooth) * fade
            if t > duration * .91: sample += math.sin(2*math.pi*90*t) * .18 * math.exp(-(t-duration*.91)*43)
        elif name == 'elevator_move':
            fade = min(1.0, t * 2.2, max(0.0, (duration-t) * 2.2))
            sample = (math.sin(2*math.pi*38*t)*.15 + math.sin(2*math.pi*72*t)*.12 + smooth*.09) * fade
        else:
            raise ValueError(name)
        samples.append(max(-1.0, min(1.0, sample * .83)))
    return struct.pack('<' + 'h'*len(samples), *(round(x*32767) for x in samples))


def write(destination: Path):
    destination.mkdir(parents=True, exist_ok=True)
    for name, duration, seed in [('splash', .46, 18), ('elevator_door', 1.35, 127), ('elevator_move', 4.1, 210)]:
        with wave.open(str(destination / (name + '.wav')), 'wb') as fd:
            fd.setnchannels(1)
            fd.setsampwidth(2)
            fd.setframerate(RATE)
            fd.writeframes(render(name, duration, seed))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('output', type=Path)
    write(parser.parse_args().output)
    print('Generated splash / elevator door / elevator travel PCM: PASS')
