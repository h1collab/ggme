"""Run real headless Godot ENet sessions, including an abrupt client death."""
import argparse
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
script = 'faceless2/backrooms_network_checks.gd' if (Path(args.project) / 'faceless2/backrooms_network_checks.gd').exists() else 'scripts/backrooms_network_checks.gd'
processes = {}
handles = []

def start(role):
    handle = (out / ('p2p-' + role + '.log')).open('w')
    handles.append(handle)
    processes[role] = subprocess.Popen([args.godot, '--headless', '--path', args.project, '--script', script, '--', '--role=' + role, '--port=' + str(port)], stdout=handle, stderr=subprocess.STDOUT)

def wait_marker(role, marker, seconds):
    deadline = time.monotonic() + seconds
    while marker not in (out / ('p2p-' + role + '.log')).read_text():
        if processes[role].poll() is not None or time.monotonic() > deadline:
            raise RuntimeError(role + ' did not reach ' + marker + '\n' + (out / ('p2p-' + role + '.log')).read_text())
        time.sleep(.1)

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
    start('drophost')
    wait_marker('drophost', 'DROP_HOST_READY', 8)
    start('dropclient')
    wait_marker('dropclient', 'DROP_ACTION_REPLICATED', 12)
    wait_marker('drophost', 'DROP_ACTION_RECEIVED', 3)
    # No leave RPC or clean shutdown: the host must reclaim a dead UDP peer.
    processes['dropclient'].kill()
    processes['dropclient'].wait(timeout=3)
    code = processes['drophost'].wait(timeout=23)
    for role in ('drophost', 'dropclient'):
        text = (out / ('p2p-' + role + '.log')).read_text()
        assert 'ERROR:' not in text and 'FAIL:' not in text, role + '\n' + text
    assert code == 0 and 'P2P drophost: PASS' in (out / 'p2p-drophost.log').read_text()
    print('Faceless 2 P2P checks: PASS / real UDP host, client, late join, wrong-key rejection, actions, movement, layer transition, graceful disconnect, killed-client slot and avatar cleanup')
finally:
    for process in processes.values():
        if process.poll() is None:
            process.terminate()
            try: process.wait(timeout=3)
            except subprocess.TimeoutExpired: process.kill()
    for handle in handles: handle.close()
