"""Run four real Godot processes over ENet UDP. No mocks or fabricated snapshots."""
import argparse
import os
from pathlib import Path
import socket
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('--godot', default='godot')
parser.add_argument('--project', default='app')
parser.add_argument('--output', default='qa')
args = parser.parse_args()
out = Path(args.output)
out.mkdir(parents=True, exist_ok=True)
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
    s.bind(('127.0.0.1', 0))
    port = s.getsockname()[1]
processes = {}
handles = []

def start(role):
    handle = (out / ('p2p-' + role + '.log')).open('w')
    handles.append(handle)
    processes[role] = subprocess.Popen([args.godot, '--headless', '--path', args.project, '--script', 'scripts/backrooms_network_checks.gd', '--', '--role=' + role, '--port=' + str(port)], stdout=handle, stderr=subprocess.STDOUT)

try:
    start('host')
    deadline = time.monotonic() + 8
    while 'HOST_READY' not in (out / 'p2p-host.log').read_text():
        if processes['host'].poll() is not None or time.monotonic() > deadline:
            raise RuntimeError('Host could not start: ' + (out / 'p2p-host.log').read_text())
        time.sleep(.1)
    start('client')
    start('reject')
    time.sleep(3)
    start('late')
    for role, process in processes.items():
        code = process.wait(timeout=25)
        text = (out / ('p2p-' + role + '.log')).read_text()
        assert code == 0 and 'P2P ' + role + ': PASS' in text and 'ERROR:' not in text and 'FAIL:' not in text, role + '\n' + text
    print('Backrooms P2P checks: PASS / real UDP host, client, late join, wrong-key rejection, actions, movement, layer transition, disconnect')
finally:
    for process in processes.values():
        if process.poll() is None:
            process.terminate()
            try: process.wait(timeout=3)
            except subprocess.TimeoutExpired: process.kill()
    for handle in handles: handle.close()
