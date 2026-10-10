"""Node.js lobby + independent REAL Godot headless ENet host/client via room code."""
import argparse
import os
from pathlib import Path
import socket
import subprocess
import time

p = argparse.ArgumentParser()
p.add_argument('--godot', default='godot')
p.add_argument('--project', default='app')
p.add_argument('--output', default='qa')
args = p.parse_args()
output = Path(args.output)
output.mkdir(parents=True, exist_ok=True)
with socket.socket() as sock:
    sock.bind(('127.0.0.1', 0))
    http_port = sock.getsockname()[1]
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
    sock.bind(('127.0.0.1', 0))
    udp_port = sock.getsockname()[1]
url = f'http://127.0.0.1:{http_port}'
service = subprocess.Popen(['node','matchmaking/server.mjs'], env={**os.environ,'PORT':str(http_port)}, stdout=subprocess.DEVNULL,stderr=subprocess.STDOUT)
script = 'faceless2/backrooms_room_checks.gd' if (Path(args.project)/'faceless2/backrooms_room_checks.gd').exists() else 'scripts/backrooms_room_checks.gd'
procs = []
handles = []
def spawn(role,code=''):
    log = (output/f'room-{role}.log').open('w')
    handles.append(log)
    cmd = [args.godot,'--headless','--path',args.project,'--script',script,'--',f'--role={role}',f'--directory={url}',f'--udp-port={udp_port}']
    if code: cmd.append(f'--room={code}')
    proc = subprocess.Popen(cmd,stdout=log,stderr=subprocess.STDOUT)
    procs.append(proc)
    return proc
try:
    # Health check: the Node process must really be listening, not mocked.
    from urllib.request import urlopen
    for _ in range(80):
        try:
            with urlopen(url+'/health',timeout=0.5) as resp:
                assert resp.status == 200
            break
        except OSError: time.sleep(0.05)
    else: raise RuntimeError('JS matchmaking service unavailable')
    host=spawn('host')
    code=None
    for _ in range(240):
        lines=(output/'room-host.log').read_text()
        for line in lines.splitlines():
            if 'ROOM_READY ' in line: code=line.strip().split('ROOM_READY ')[1].strip()
        if code: break
        if host.poll() is not None: raise RuntimeError('Godot host failed to register room: '+lines)
        time.sleep(0.1)
    assert code and len(code) == 8, 'No valid room code from JS HTTP + Godot'
    client=spawn('client',code)
    for role,proc in [('client',client),('host',host)]:
        proc.wait(timeout=35)
        text=(output/f'room-{role}.log').read_text()
        assert proc.returncode == 0 and f'Faceless 2 room directory {role}: PASS' in text, role+'\n'+text
        assert 'ERROR:' not in text and 'FAIL:' not in text,role+'\n'+text
    print('Faceless 2 room directory: PASS / Node.js public room code + two real Godot headless ENet peers, no IP input, host cap 2, authenticated pickup synchronization')
finally:
    for proc in procs + [service]:
        if proc.poll() is None:
            proc.terminate()
            try: proc.wait(timeout=2)
            except subprocess.TimeoutExpired: proc.kill()
    for h in handles: h.close()
