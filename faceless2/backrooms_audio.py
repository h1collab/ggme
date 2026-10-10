"""Deterministic original ambience: machinery and footsteps, no creature cues."""
import math
import random
import struct
import sys
import wave
from pathlib import Path

out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)
rng = random.Random(11)
rate = 22050

def save(name, seconds, sample, loop=False):
    data = []
    for i in range(int(seconds * rate)):
        t = i / rate
        v = sample(t, rng.uniform(-1, 1))
        data.append(struct.pack('<h', int(max(-1, min(1, v)) * 32767)))
    with wave.open(str(out / name), 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(rate)
        f.writeframes(b''.join(data))
    if loop:
        # Resource importer settings are created by Godot; runtime sets WAV loop mode.
        pass

save('roomtone.wav', 8, lambda t, n: .13 * math.sin(2 * math.pi * 60 * t) + .045 * math.sin(2 * math.pi * 120 * t) + .025 * n, True)
save('footstep.wav', .25, lambda t, n: math.exp(-t * 24) * (.20 * n + .13 * math.sin(2 * math.pi * 95 * t)))
save('relay.wav', .25, lambda t, n: math.exp(-t * 42) * (.08 * n + .12 * math.sin(2 * math.pi * 480 * t)))
print('Backrooms ambience: 3 original WAV files')
