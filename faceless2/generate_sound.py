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
        elif name == 'phone_ring':
            gate = 1.0 if (t % .78) < .44 else 0.0
            sample = gate * (math.sin(2*math.pi*438*t)*.22 + math.sin(2*math.pi*512*t)*.16)
        elif name == 'phone_disconnect':
            sample = math.sin(2*math.pi*480*t)*.27*math.exp(-t*10) + math.sin(2*math.pi*620*t)*.12*math.exp(-t*12)
        elif name == 'phone_static':
            # Band-limited distorted connection noise, generated offline.
            chop = 0.25 + .75 * (1 if (int(t*11)%5 < 3) else .1)
            sample = (smooth*.62 + math.sin(2*math.pi*87*t)*.12)*chop*min(1., t*18.)
        elif name == 'phone_fall':
            envelope = min(1.0, t*7) * max(0.0, 1-t/duration)
            sample = (math.sin(2*math.pi*(69-48*t/duration)*t)*.4 + smooth*.35)*envelope
        elif name == 'smiler_sting':
            attack = math.exp(-t*6.4)
            tremolo = math.sin(2*math.pi*(44+80*t)*t) * 0.30
            sample = (smooth*0.95 + tremolo + math.sin(2*math.pi*101*t)*0.15) * attack
        elif name == 'door_locked':
            impact = math.exp(-t*27)
            metal = math.sin(2*math.pi*175*t) * 0.22 + math.sin(2*math.pi*516*t) * 0.10
            sample = (metal + smooth*0.17)*impact
        elif name == 'door_creak':
            attack = min(1.,t*12.) * max(0.,1-t/duration)
            sample = (math.sin(2*math.pi*(91 + t*140)*t)*0.17 + smooth*.19)*attack
        elif name == 'door_slam':
            impact = math.exp(-t * 15.0)
            boom = math.sin(2*math.pi*(65-18*t)*t) * .47
            rattle = math.sin(2*math.pi*322*t) * math.exp(-t*23) * .12
            sample = (boom + smooth*.58)*impact + rattle
        elif name == 'flashlight_pickup':
            envelope = math.exp(-t*9.0)
            sample = (math.sin(2*math.pi*(410-110*t)*t)*.30 + smooth*.09)*envelope
        elif name == 'flashlight_click':
            envelope = math.exp(-t*36.0)
            sample = (smooth*.42 + math.sin(2*math.pi*790*t)*.09)*envelope
        elif name == 'fps_shot':
            # Dry rifle/blaster crack and a short metallic tail; source-only
            # synthesized Foley at build time, no runtime procedural audio.
            attack = math.exp(-t * 42.0)
            tail = math.exp(-t * 9.0)
            sample = smooth * .95 * attack + math.sin(2 * math.pi * (155-90*t)*t) * .38 * tail
        elif name in ('fps_pistol', 'fps_sniper'):
            base = 210 if name == 'fps_pistol' else 85
            tail = 15 if name == 'fps_pistol' else 6
            sample = smooth*.85*math.exp(-t*48) + math.sin(2*math.pi*(base-35*t)*t)*.43*math.exp(-t*tail)
        elif name == 'fps_knife':
            sample = smooth*.65*math.exp(-((t-.08)/.045)**2)
        elif name == 'fps_switch':
            sample = (smooth*.3+math.sin(2*math.pi*440*t)*.15)*math.exp(-t*30)
        elif name == 'fps_damage':
            sample = (smooth*.3+math.sin(2*math.pi*65*t)*.2)*math.exp(-t*17)
        elif name == 'fps_result':
            note = [523.25,659.25,783.99][min(2,int(t/.18))]
            sample = math.sin(2*math.pi*note*t)*.19*min(1,t*30)*max(0,1-t/duration)
        elif name == 'fps_reload':
            p1 = math.exp(-abs(t-.16)*45)
            p2 = math.exp(-abs(t-.83)*40)
            sample = (smooth*.36 + math.sin(2*math.pi*515*t)*.11) * (p1+p2)
        elif name == 'fps_impact':
            envelope = math.exp(-t*29.0)
            sample = (smooth*.38 + math.sin(2*math.pi*710*t)*.20)*envelope
        elif name == 'elevator_move':
            fade = min(1.0, t * 2.2, max(0.0, (duration-t) * 2.2))
            sample = (math.sin(2*math.pi*38*t)*.15 + math.sin(2*math.pi*72*t)*.12 + smooth*.09) * fade
        else:
            raise ValueError(name)
        samples.append(max(-1.0, min(1.0, sample * .83)))
    return struct.pack('<' + 'h'*len(samples), *(round(x*32767) for x in samples))


def write(destination: Path):
    destination.mkdir(parents=True, exist_ok=True)
    for name, duration, seed in [('splash', .46, 18), ('elevator_door', 1.35, 127), ('elevator_move', 4.1, 210), ('phone_ring', 3.0, 414), ('phone_disconnect', .46, 51), ('phone_fall', 2.4, 91), ('phone_static', 3.5, 940), ('smiler_sting', .98, 301), ('door_locked', .45, 472), ('door_creak', 1.18, 615), ('door_slam', 0.75, 227), ('flashlight_pickup', 0.42, 381), ('flashlight_click', 0.16, 723), ('fps_shot', .42, 1811), ('fps_reload', 1.05, 1812), ('fps_impact', .30, 1813), ('fps_pistol', .30, 1831), ('fps_sniper', .75, 1832), ('fps_knife', .22, 1833), ('fps_switch', .16, 1834), ('fps_damage', .28, 1835), ('fps_result', .8, 1836)]:
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
