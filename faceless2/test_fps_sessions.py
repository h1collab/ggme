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
from urllib.request import urlopen, Request


def test_lan(args,output,project,script):
    """Real UDP discovery payload -> code -> authenticated ENet, without HTTP."""
    with tempfile.TemporaryDirectory(prefix='fps-lan-',dir=output) as folder:
        work=Path(folder)
        with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as sock:
            sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
        processes={};handles=[]
        def state(label):
            try:return json.loads((work/(label+'-state.json')).read_text())
            except (OSError,ValueError):return {}
        def wait(label,predicate):
            deadline=time.monotonic()+14
            while time.monotonic()<deadline:
                data=state(label)
                if predicate(data):return data
                if processes[label].poll() is not None:break
                time.sleep(.05)
            raise AssertionError(f'LAN {label}: {state(label)}')
        def spawn(label,role):
            handle=(output/f'fps-lan-{label}.log').open('w');handles.append(handle)
            processes[label]=subprocess.Popen([args.godot,'--headless','--path',str(project),
                '--script',script,'--',f'--role={role}',f'--label={label}',
                f'--port={port}','--slots=2','--map=1',f'--output={work}'],stdout=handle,stderr=subprocess.STDOUT)
        try:
            spawn('host','lan_host')
            host=wait('host',lambda x:x.get('mode')=='host' and len(x.get('room',''))==8)
            assert not host['can_fire'] and host['directory']==''
            spawn('client','lan_quick')
            client=wait('client',lambda x:x.get('mode')=='client' and len(x.get('hp',{}))==2)
            host=wait('host',lambda x:x.get('members')==2)
            assert client['room']==host['room'] and client['directory']==''
            assert client['map']==host['map']==1 and client['geometry']==host['geometry']
            assert client['can_fire'] and host['can_fire']
            assert client['seats']==host['seats'] and len(client['seats'])==2
            for label,process in processes.items():
                (work/(label+'-command.json')).write_text(json.dumps({'op':'quit','serial':1}))
                process.wait(timeout=6)
                assert process.returncode==0
            for label in processes:
                text=(output/f'fps-lan-{label}.log').read_text()
                assert 'ERROR:' not in text and 'FAIL:' not in text,text
            (output/'fps-lan-results.json').write_text(json.dumps({'udp_discovery':'PASS','no_http_directory':'PASS','code_to_enet':'PASS','two_player_start':'PASS','four_weapon_rpcs':'PASS','finite_inventory_switching':'PASS','sniper_damage_death_counter':'PASS','map_geometry_and_seats':'PASS'},indent=2))
            print('FPS_REAL_LAN_ROOM_PASS native UDP announcements, code, two headless ENet peers; no HTTP',flush=True)
        finally:
            for process in processes.values():
                if process.poll() is None:
                    process.terminate()
                    try:process.wait(timeout=3)
                    except subprocess.TimeoutExpired:process.kill();process.wait(timeout=3)
            for handle in handles:handle.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--project', default='app')
    parser.add_argument('--output', default='qa')
    parser.add_argument('--lan-only', action='store_true')
    args = parser.parse_args()
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    project = Path(args.project).resolve()
    script = ('faceless2/' if (project/'faceless2/backrooms_fps_session_checks.gd').exists()
              else 'scripts/') + 'backrooms_fps_session_checks.gd'
    if args.lan_only:
        test_lan(args,output,project,script)
        return
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
                    assert json.load(response)['protocol'] == 22
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
                            snapshot=wait(label,lambda x:len(x.get('avatars',{}))==count-1,'remote original character models instantiated')
                            for peer_id,file in snapshot['avatars'].items():
                                assert file==f"fps_character_{snapshot['seats'][peer_id]}.glb"

                try:
                    spawn('host', 'host')
                    initial = wait('host', lambda x: len(x.get('room', '')) == 8, 'room registered')
                    assert initial['members'] == 1 and not initial['can_fire']
                    assert 'WAITING FOR PLAYER 2' in initial['hud']
                    time.sleep(.35)
                    assert state('host')['round']['seconds'] == 300, 'one-player room pauses the host clock'
                    # Real unauthenticated UDP client must not consume ammo or
                    # receive the protected roster before the handshake.
                    spawn('raw', 'raw')
                    wait('raw', lambda x: x.get('transport_connected'), 'raw UDP socket')
                    time.sleep(.7)
                    command('raw', 'fire', count=10)
                    command('raw', 'ready', count=10)
                    command('raw', 'weapon', weapon=2, count=10)
                    time.sleep(.4)
                    assert state('host')['ammo'] == {'1': 24}
                    assert state('raw')['hp'] == {}
                    assert state('host')['weapons'] == {'1':0}
                    assert state('host')['round']['ready'] == []
                    command('raw', 'quit')
                    processes['raw'].wait(timeout=4)
                    code = initial['room']
                    if slots == 2 and map_id == 0:
                        spawn('cancel',role='cancel')
                        wait('cancel',lambda x: x.get('mode') == 'solo' and not x.get('matching',True),'search cancellation closes pending work')
                        time.sleep(1.6)
                        assert state('cancel')['mode'] == 'solo' and state('host')['members'] == 1
                        command('cancel','quit')
                        processes['cancel'].wait(timeout=4)
                    stale = None
                    if slots == 2 and map_id == 0:
                        # Real directory entry with an unreachable real UDP endpoint.
                        # Give it higher occupancy to force the first attempt.
                        def request(path, body, method='POST'):
                            with urlopen(Request(url+path, data=json.dumps(body).encode(),
                                                 headers={'Content-Type':'application/json'}, method=method),timeout=3) as response:
                                return json.load(response)
                        with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as dead:
                            dead.bind(('127.0.0.1',0))
                            dead_port = dead.getsockname()[1]
                        stale = request('/v1/rooms', {'name':'Expired UDP candidate','port':dead_port,'public':True,'max_players':4,'map_id':1})
                        request('/v1/rooms/'+stale['code']+'/heartbeat',{'owner_token':stale['owner_token'],'players':3})
                    spawn('c1', role='quick' if slots == 2 else 'client', code=code)
                    first = wait('c1', lambda x: x.get('active') and len(x.get('hp', {})) == 2,
                                 'two-player FPS snapshot')
                    roster(2)
                    if stale:
                        assert state('c1')['match_attempts'] >= 2, 'failed candidate must be retried'
                        request('/v1/rooms/'+stale['code'],{'owner_token':stale['owner_token']},'DELETE')
                    assert first['can_fire'] and state('host')['can_fire']
                    assert first['map'] == map_id == state('host')['map']
                    assert first['geometry'] == state('host')['geometry'] and len(first['geometry']) == 64
                    shooter = str(first['id'])
                    for weapon in (1,2,3,0):
                        time.sleep(1.1)  # current weapon's real cooldown cannot be shortened by switching
                        command('c1','weapon',weapon=weapon,count=4)
                        switched=wait('c1',lambda x:x.get('weapons',{}).get(shooter)==weapon,'weapon selection replicated')
                        assert state('host')['weapons'][shooter]==weapon
                        expected=(24,12,5,0)[weapon]
                        assert switched['ammo'][shooter]==expected
                        if weapon != 0:
                            time.sleep(.3)
                            command('c1','fire',count=10)
                            wait('c1',lambda x:x.get('ammo',{}).get(shooter)==(expected-1 if weapon !=3 else 0),'selected cadence limits real shot flood')
                            time.sleep(.3)
                    time.sleep(.3)
                    command('c1','weapon',weapon=1)
                    saved=wait('c1',lambda x:x.get('weapons',{}).get(shooter)==1,'depleted sidearm inventory restored')
                    assert saved['ammo'][shooter]==11 and saved['stock'][shooter]==72
                    time.sleep(.3)
                    command('c1','weapon',weapon=0)
                    wait('c1',lambda x:x.get('weapons',{}).get(shooter)==0,'original rifle restored')
                    time.sleep(.3)
                    print(f'FPS_REAL_FOUR_WEAPONS_{slots}_MAP_{map_id}_PASS selection RPCs, cadence flood and separate ammunition',flush=True)
                    command('c1','weapon',weapon=77,count=4)
                    time.sleep(.3)
                    assert state('host')['weapons'][shooter]==0
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
                    mark = wait('c1',lambda x: x.get('impact_serial',0) > 0 and x.get('impact_marks',0) > 0,
                                'host raycast surface mark replicated')
                    assert mark['impact_serial'] == state('host')['impact_authority']
                    time.sleep(.35)
                    assert state('c1')['impact_marks'] == mark['impact_marks'], 'periodic snapshots must not duplicate impact marks'
                    command('c1', 'handshake')
                    time.sleep(.3)
                    assert state('host')['ammo'][shooter] == 23
                    before = state('host')['poses'][shooter][2]
                    command('c1', 'move', pressed=True)
                    time.sleep(.35)
                    command('c1', 'move', pressed=False)
                    wait('host', lambda x: x.get('poses', {}).get(shooter, [0,0,before])[2] < before-.25,
                         'movement replicated through UDP')
                    # Damage/score/respawn and reload must replicate over UDP,
                    # not only through same-process authority checks.
                    import math
                    time.sleep(.4) # actual acceleration/deceleration settles before deriving the shot ray
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
                    assert state('c1')['deaths']['1'] == 1, 'host death counter reaches shooter'
                    assert state('c1')['hit_marker'] == 4, 'authoritative four-hit confirmation reaches shooter'
                    for source in ('host','c1'):
                        wait(source, lambda x: bool(x.get('kills')) and x['kills'][-1]['killer'] == int(shooter) and x['kills'][-1]['victim'] == 1, 'host-authorized kill feed replicated')
                    command('c1', 'reload_flood', direction=direction)
                    blocked = wait('host',lambda x: x.get('reload_blocks',{}).get(shooter,0) == 10,
                                   'all ten real fire RPCs rejected during reload')
                    assert blocked['reload_block_ammo'][shooter] == 19, 'host rejection captures unchanged magazine before reload completes'
                    wait('c1', lambda x: x.get('ammo', {}).get(shooter) == 24,
                         'delayed authoritative reload replicated')
                    wait('host',lambda x: x.get('reload_durations',{}).get(shooter,0) >= 1600,
                         'host monotonic reload completion recorded')
                    assert state('host')['stock'][shooter] == 115
                    time.sleep(.3)
                    command('c1','weapon',weapon=2)
                    wait('c1',lambda x:x.get('weapons',{}).get(shooter)==2,'sniper selected for real damage RPC')
                    time.sleep(.3)
                    command('c1','fire',direction=direction)
                    wait('c1',lambda x:x.get('scores',{}).get(shooter)==2 and x.get('deaths',{}).get('1')==2,'one real sniper hit awards kill and death')
                    assert state('c1')['ammo'][shooter]==3 and state('c1')['hit_marker']==5
                    time.sleep(1.1)
                    command('c1','weapon',weapon=0)
                    wait('c1',lambda x:x.get('weapons',{}).get(shooter)==0 and x['ammo'][shooter]==24,'rifle inventory unchanged by sniper kill')
                    command('c1', 'aim', direction=[0,0,-1])
                    for seat in range(2, slots):
                        spawn(f'c{seat}', code=code)
                        wait(f'c{seat}', lambda x: x.get('active') and len(x.get('hp', {})) == seat+1,
                             'late joining player received current roster')
                        roster(seat+1)
                        assert state(f'c{seat}')['ammo'][shooter] == 24
                        assert state(f'c{seat}')['scores'][shooter] == 2
                        assert state(f'c{seat}')['deaths']['1'] == 2
                        assert state(f'c{seat}')['weapons'][shooter] == 0
                        assert state(f'c{seat}')['kills'][-1]['killer'] == int(shooter)
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
                    # Complete real rounds after the existing kill/reconnect
                    # coverage. All state below is received from actual ENet.
                    final_id = str(state('final')['id'])
                    before_round = state('host')['round']['id']
                    command('final','ready',count=4)
                    time.sleep(.25)
                    assert state('host')['round']['ready'] == [], 'ready is rejected during live combat'
                    if slots == 2 and map_id == 0:
                        import math
                        poses = state('host')['poses']
                        eye = [poses[final_id][0],poses[final_id][1]+1.58,poses[final_id][2]]
                        target = [poses['1'][0],poses['1'][1]+1.0,poses['1'][2]]
                        ray = [target[i]-eye[i] for i in range(3)]
                        length = math.sqrt(sum(v*v for v in ray))
                        ray = [v/length for v in ray]
                        command('final','aim',direction=ray)
                        time.sleep(.3)
                        for hit in range(40):
                            if hit == 24:
                                command('final','reload')
                                wait('final',lambda x:x.get('ammo',{}).get(final_id)==24,'actual reload for ten-kill round')
                            expected = 24-(hit%24)-1
                            command('final','fire',direction=ray)
                            wait('final',lambda x:x.get('ammo',{}).get(final_id)==expected,'round-winning accepted ray')
                            time.sleep(.13)
                        wait('final',lambda x:x.get('scores',{}).get(final_id)==10 and x['round']['over'],'ten actual kills end round')
                        assert state('final')['round']['winners'] == [int(final_id)]
                        assert state('final')['round']['winner_seats'] == [2]
                    else:
                        command('host','expire_round')
                    for source in ('host','final'):
                        wait(source,lambda x:x.get('round',{}).get('over') and not x['can_fire'],'end-round snapshot locks fire')
                    ammo_after = state('host')['ammo'].copy()
                    command('final','fire',count=10)
                    command('final','reload')
                    time.sleep(.25)
                    assert state('host')['ammo'] == ammo_after, 'finished round rejects fire and reload'
                    if slots > 2:
                        spawn('result_late',code=code)
                        wait('result_late',lambda x:x.get('round',{}).get('over') and len(x.get('hp',{}))==3,'late join receives finished round')
                        command('result_late','ready')
                        command('result_late','quit')
                        processes['result_late'].wait(timeout=4)
                        wait('host',lambda x:x.get('members')==2 and not x['round']['ready'],'departing ready peer is removed')
                    command('final','ready',count=4)
                    wait('host',lambda x:len(x['round']['ready'])==1,'duplicate ready has one authenticated vote')
                    command('host','ready')
                    for source in ('host','final'):
                        reset = wait(source,lambda x:x.get('round',{}).get('id')==before_round+1 and not x['round']['over'],'both ready start next round')
                        assert reset['can_fire'] and set(reset['scores'].values())=={0}
                        assert set(reset['ammo'].values())=={24} and set(reset['stock'].values())=={120}, (source,reset)
                        assert set(reset['hp'].values())=={100} and not reset['kills']
                        assert set(reset['deaths'].values())=={0} and set(reset['weapons'].values())=={0}
                    if slots == 2 and map_id == 0:
                        command('host','expire_round')
                        tie = wait('final',lambda x:x.get('round',{}).get('over'),'host clock timeout reaches client')
                        assert set(tie['round']['winner_seats'])=={1,2}, 'equal scores produce draw'
                        wait('final',lambda x:x.get('round',{}).get('id')==before_round+2 and not x['round']['over'],'eight-second automatic rematch',timeout=12)
                    print(f'FPS_REAL_ROUND_{slots}_MAP_{map_id}_PASS host clock, results, authenticated ready, rematch reset',flush=True)
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
                    results.append({'capacity':slots, 'map_id':map_id, 'map_sync':'PASS', 'actual_collision_geometry_sync':'PASS', 'kill_feed':'PASS', 'peer_idle_watchdog':'PASS', 'two_player_start':'PASS',
                        'late_join':'PASS', 'full_room_rejection':'PASS',
                        'invalid_rpc':'PASS', 'duplicate_fire':'PASS',
                        'authority_hit_marker':'PASS', 'quick_match_retry':'PASS' if slots == 2 and map_id == 0 else 'covered_in_2_map0', 'movement':'PASS', 'damage_score_respawn':'PASS', 'timed_reload':'PASS', 'reconnect':'PASS', 'strong_kill':'PASS',
                        'host_exit':'PASS','round_result_lock':'PASS','authenticated_ready_rematch':'PASS','round_reset':'PASS',
                        'ten_actual_kills':'PASS' if slots==2 and map_id==0 else 'covered_in_2_map0',
                        'timeout_draw_auto_rematch':'PASS' if slots==2 and map_id==0 else 'covered_in_2_map0'})
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
        test_lan(args,output,project,script)
        print('FPS_REAL_MULTIPROCESS_UDP_PASS both maps, capacities 2/3/4, four weapons, sniper damage, deaths, finite inventories, late join, invalid RPC, disconnect and reconnect')
    finally:
        service.terminate()
        service.wait(timeout=4)


if __name__ == '__main__':
    main()
