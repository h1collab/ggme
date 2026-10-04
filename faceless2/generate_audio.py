import math, os, struct, sys, wave, random

OUT = sys.argv[1] if len(sys.argv) > 1 else "audio"
os.makedirs(OUT, exist_ok=True)
RATE = 22050

def write_wav(name, seconds, fn):
    n = int(RATE * seconds)
    with wave.open(os.path.join(OUT, name), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = bytearray()
        for i in range(n):
            t = i / RATE
            v = max(-1.0, min(1.0, fn(t)))
            frames += struct.pack("<h", int(v * 32767))
        w.writeframes(frames)

rng = random.Random(917)
write_wav("blackwood_ambience.wav", 10.0, lambda t:
    0.045*math.sin(2*math.pi*43*t) +
    0.025*math.sin(2*math.pi*67*t) +
    0.012*(rng.random()*2-1)
)
write_wav("signal_static.wav", 1.3, lambda t:
    (0.20*(rng.random()*2-1) + 0.05*math.sin(2*math.pi*190*t))*max(0.0, 1.0-t/1.3)
)
write_wav("chase_pulse.wav", 6.0, lambda t:
    0.10*math.sin(2*math.pi*(70+18*math.sin(t*1.9))*t) + 0.02*(rng.random()*2-1)
)
print("audio generated")
