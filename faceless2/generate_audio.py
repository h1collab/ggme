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
write_wav("pistol_shot.wav", 0.22, lambda t:
    (0.55*(rng.random()*2-1) + 0.22*math.sin(2*math.pi*120*t))*math.exp(-18*t)
)
write_wav("rifle_shot.wav", 0.18, lambda t:
    (0.72*(rng.random()*2-1) + 0.28*math.sin(2*math.pi*95*t))*math.exp(-22*t)
)
write_wav("reload_click.wav", 0.52, lambda t:
    (0.18*math.sin(2*math.pi*820*t) if t < 0.08 else 0.11*math.sin(2*math.pi*430*t))*math.exp(-5*t)
)
write_wav("footstep.wav", 0.22, lambda t:
    (0.20*(rng.random()*2-1)+0.10*math.sin(2*math.pi*75*t))*math.exp(-14*t)
)
write_wav("footstep_run.wav", 0.18, lambda t:
    (0.26*(rng.random()*2-1)+0.13*math.sin(2*math.pi*68*t))*math.exp(-16*t)
)
write_wav("heartbeat.wav", 1.0, lambda t:
    0.20*math.sin(2*math.pi*52*t)*math.exp(-24*((t%0.5)))
)
write_wav("radio_beep.wav", 0.20, lambda t:
    0.16*math.sin(2*math.pi*980*t)*math.exp(-8*t)
)
print("audio generated")
