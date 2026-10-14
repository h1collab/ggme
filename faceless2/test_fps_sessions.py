"""Full-capacity FPS rooms using separate real Godot headless UDP processes.

Commands/status files only coordinate the harness; they never provide game
state to another Godot process. Assertions inspect actual received ENet state.
"""
import argparse
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time
from urllib.request import urlopen


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--project', default='app')
    parser.add_argument('--output', default='qa')
    args = parser.parse_args()
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    project = Path(args.project).resolve()
    script = ('faceless2/' if (project/'faceless2/backrooms_fps_session_checks.gd').exists()
              else 'scripts/') + 'backrooms_fps_session_checks.gd'
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        http_port = sock.getsockname()[1]
    service = subprocess.Popen(['node', 'matchmaking/server.mjs'],
                               env={**os.environ, 'PORT': str(http_port)},
                               stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
    url = f'http://127.0.0.1:{http_port}'
    results = []
    try:
        for _ in range(100):
            try:
                with urlopen(url+'/health', timeout=.5) as response:
                    assert json.load(response)['protocol'] == 19
                break
            except OSError:
                time.sleep(.05)
        else:
            raise AssertionError('Node directory did not start')
        for slots, map_id in ((2,0),(2,1),(3,0),(3,1),(4,0),(4,1)):
            with tempfile.TemporaryDirectory(prefix=f'fps-{slots}-map{map_id}-', dir=output) as folder:
                work = Path(folder)
                processes, handles = {}, []
                sequence = 0
                with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
                    sock.bind(('127.0.0.1', 0))
                    port = sock.getsockname()[1]

                def state(label):
                    try:
                        return json.loads((work/(label+'-state.json')).read_text())
                    except (OSError, ValueError):
                        return {}

                def wait(label, predicate, detail, timeout=15):
                    deadline = time.monotonic()+timeout
                    while time.monotonic() < deadline:
                        value = state(label)
                        if predicate(value):
                            return value
                        if processes[label].poll() is not None:
                            break
                        time.sleep(.1)
                    log = (output/f'fps-{slots}-map{map_id}-{label}.log').read_text()
                    raise AssertionError(f'{slots}/{label}: {detail}\n{state(label)}\n{log}')

                def spawn(label, role='client', code=''):
                    log = (output/f'fps-{slots}-map{map_id}-{label}.log').open('w')
                    handles.append(log)
                    command = [args.godot, '--headless', '--path', str(project),
                               '--script', script, '--', f'--role={role}',
                               f'--label={label}', f'--directory={url}',
                               f'--port={port}', f'--slots={slots}', f'--map={map_id}',
                               f'--room={code}', f'--output={work}']
                    processes[label] = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)

                def command(label, op, **extra):
                    nonlocal sequence
                    sequence += 1
                    target = work/(label+'-command.json')
                    temporary = target.with_suffix('.tmp')
                    temporary.write_text(json.dumps({'serial': sequence, 'op': op, **extra}))
                    temporary.replace(target)
                    if op != 'quit':
                        wait(label, lambda x: x.get('serial') == sequence, 'command acknowledged')

                def roster(count):
                    for label, process in processes.items():
                        if process.poll() is None and label not in ('raw', 'overflow'):
                            wait(label, lambda x: len(x.get('hp', {})) == count,
                                 f'combat roster {count} replicated')

                try:
                    spawn('host', 'host')
                    initial = wait('host', lambda x: len(x.get('room', '')) == 8, 'room registered')
                    assert initial['members'] == 1 and not initial['can_fire']
                    assert 'WAITING FOR PLAYER 2' in initial['hud']
                    # Real unauthenticated UDP client must not consume ammo or
                    # receive the protected roster before the handshake.
                    spawn('raw', 'raw')
                    wait('raw', lambda x: x.get('transport_connected'), 'raw UDP socket')
                    time.sleep(.7)
                    command('raw', 'fire', count=10)
                    time.sleep(.4)
                    assert state('host')['ammo'] == {'1': 24}
                    assert state('raw')['hp'] == {}
                    command('raw', 'quit')
                    processes['raw'].wait(timeout=4)
                    code = initial['room']
                    spawn('c1', role='quick' if slots == 2 else 'client', code=code)
                    first = wait('c1', lambda x: x.get('active') and len(x.get('hp', {})) == 2,
                                 'two-player FPS snapshot')
                    roster(2)
                    assert first['can_fire'] and state('host')['can_fire']
                    assert first['map'] == map_id == state('host')['map']
                    assert first['geometry'] == state('host')['geometry'] and len(first['geometry']) == 64
                    shooter = str(first['id'])
                    command('c1', 'fire', direction=[100, 0, 0], count=8)
                    command('c1', 'fire', direction=[0, 0, 1], count=8)
                    command('c1', 'fire', direction=[0, .9, -.435889894], count=8)
                    command('c1', 'pose')
                    time.sleep(.4)
                    assert state('host')['ammo'][shooter] == 24
                    assert abs(state('host')['poses'][shooter][0]) < 24
                    command('c1', 'fire', count=10)
                    wait('c1', lambda x: x.get('ammo', {}).get(shooter) == 23,
                         'one accepted shot despite duplicate flood')
                    assert state('host')['ammo'][shooter] == 23
                    command('c1', 'handshake')
                    time.sleep(.3)
                    assert state('host')['ammo'][shooter] == 23
                    before = state('host')['poses'][shooter][2]
                    command('c1', 'move', pressed=True)
                    time.sleep(.5)
                    command('c1', 'move', pressed=False)
                    wait('host', lambda x: x.get('poses', {}).get(shooter, [0,0,before])[2] < before-.25,
                         'movement replicated through UDP')
                    # Damage/score/respawn and reload must replicate over UDP,
                    # not only through same-process authority checks.
                    import math
                    poses = state('host')['poses']
                    eye = [poses[shooter][0], poses[shooter][1]+1.58, poses[shooter][2]]
                    target = [poses['1'][0], poses['1'][1]+1.0, poses['1'][2]]
                    direction = [target[i]-eye[i] for i in range(3)]
                    length = math.sqrt(sum(v*v for v in direction))
                    direction = [v/length for v in direction]
                    command('c1', 'aim', direction=direction)
                    time.sleep(.3)
                    for shot in range(4):
                        command('c1', 'fire', direction=direction)
                        wait('c1', lambda x: x.get('ammo', {}).get(shooter) == 22-shot,
                             'damage shot acknowledged')
                        if shot < 3:
                            wait('c1', lambda x: x.get('hp', {}).get('1') == 75-25*shot,
                                 'host HP damage replicated to shooter')
                        time.sleep(.22)
                    wait('c1', lambda x: x.get('scores', {}).get(shooter) == 1 and x.get('hp', {}).get('1') == 100,
                         'score and respawn HP replicated')
                    command('c1', 'reload')
                    time.sleep(.25)
                    assert state('host')['ammo'][shooter] == 19
                    command('c1', 'fire', direction=direction, count=10)
                    time.sleep(.25)
                    assert state('host')['ammo'][shooter] == 19
                    wait('c1', lambda x: x.get('ammo', {}).get(shooter) == 24,
                         'delayed authoritative reload replicated')
                    assert state('host')['stock'][shooter] == 115
                    command('c1', 'aim', direction=[0,0,-1])
                    for seat in range(2, slots):
                        spawn(f'c{seat}', code=code)
                        wait(f'c{seat}', lambda x: x.get('active') and len(x.get('hp', {})) == seat+1,
                             'late joining player received current roster')
                        roster(seat+1)
                        assert state(f'c{seat}')['ammo'][shooter] == 24
                        assert state(f'c{seat}')['scores'][shooter] == 1
                        assert state(f'c{seat}')['map'] == map_id
                        assert state(f'c{seat}')['geometry'] == state('host')['geometry']
                    assert state('host')['members'] == slots
                    assert len(set(state('host')['seats'].values())) == slots
                    spawn('overflow', 'overflow')
                    wait('overflow', lambda x: x.get('mode') == 'solo', 'full room rejects extra UDP peer', timeout=18)
                    assert state('host')['members'] == slots
                    command('overflow', 'quit')
                    processes['overflow'].wait(timeout=4)
                    # Graceful disconnect/rejoin must reclaim seat 2.
                    command('c1', 'quit')
                    processes['c1'].wait(timeout=4)
                    wait('host', lambda x: x.get('members') == slots-1, 'graceful seat release')
                    roster(slots-1)
                    spawn('rejoin', code=code)
                    joined = wait('rejoin', lambda x: x.get('active') and len(x.get('hp', {})) == slots,
                                  'reconnect snapshot')
                    assert joined['map'] == map_id and joined['geometry'] == state('host')['geometry']
                    new_id = str(joined['id'])
                    wait('host', lambda x: x.get('seats', {}).get(new_id) == 2, 'reconnect reclaims seat 2')
                    roster(slots)
                    # No clean leave RPC: kill every client and wait for actual
                    # ENet timeout/reclaimed roster before shooting resumes.
                    for label, process in processes.items():
                        if label != 'host' and process.poll() is None:
                            process.kill()
                            process.wait(timeout=3)
                    alone = wait('host', lambda x: x.get('members') == 1 and len(x.get('hp', {})) == 1,
                                 'strong-kill cleanup returns host to waiting', timeout=23)
                    assert not alone['can_fire'] and 'WAITING FOR PLAYER 2' in alone['hud']
                    spawn('final', code=code)
                    wait('final', lambda x: x.get('active') and len(x.get('hp', {})) == 2, 'room usable after killed clients')
                    roster(2)
                    command('host', 'quit')
                    processes['host'].wait(timeout=4)
                    lost = wait('final', lambda x: x.get('mode') == 'solo' and not x.get('running'),
                                'host exit opens client lobby')
                    assert lost['panel'] == 'lobby'
                    command('final', 'quit')
                    processes['final'].wait(timeout=4)
                    for label in processes:
                        log = (output/f'fps-{slots}-map{map_id}-{label}.log').read_text()
                        assert 'ERROR:' not in log and 'FAIL:' not in log, log
                    results.append({'capacity':slots, 'map_id':map_id, 'map_sync':'PASS', 'actual_collision_geometry_sync':'PASS', 'two_player_start':'PASS',
                        'late_join':'PASS', 'full_room_rejection':'PASS',
                        'invalid_rpc':'PASS', 'duplicate_fire':'PASS',
                        'movement':'PASS', 'damage_score_respawn':'PASS', 'timed_reload':'PASS', 'reconnect':'PASS', 'strong_kill':'PASS',
                        'host_exit':'PASS'})
                    print(f'FPS_REAL_UDP_CAPACITY_{slots}_MAP_{map_id}_PASS', flush=True)
                finally:
                    for process in processes.values():
                        if process.poll() is None:
                            process.terminate()
                            try:
                                process.wait(timeout=2)
                            except subprocess.TimeoutExpired:
                                process.kill()
                                process.wait(timeout=2)
                    for handle in handles:
                        handle.close()
        (output/'fps-session-results.json').write_text(json.dumps(results, indent=2)+'\n')
        print('FPS_REAL_MULTIPROCESS_UDP_PASS both maps, capacities 2/3/4, map/geometry sync, two-player start, late join, invalid RPC, disconnect and reconnect')
    finally:
        service.terminate()
        service.wait(timeout=4)


if __name__ == '__main__':
    main()
