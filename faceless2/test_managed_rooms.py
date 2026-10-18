"""JS-supervised native server + six actual headless ENet clients, no dummy host."""
import argparse,json,os,socket,subprocess,time
from pathlib import Path
from urllib.request import Request,urlopen
p=argparse.ArgumentParser();p.add_argument('--godot',required=True);p.add_argument('--project',required=True);p.add_argument('--output',default='qa');a=p.parse_args()
out=Path(a.output).resolve();out.mkdir(parents=True,exist_ok=True)
work=out/'managed-control';work.mkdir(exist_ok=True)
with socket.socket() as s:s.bind(('127.0.0.1',0));http=s.getsockname()[1]
with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as s:s.bind(('127.0.0.1',0));udp=s.getsockname()[1]
url=f'http://127.0.0.1:{http}'
env={**os.environ,'PORT':str(http),'GODOT_SERVER_BINARY':str(Path(a.godot).resolve()),'GODOT_SERVER_PROJECT':str(Path(a.project).resolve()),'GAME_PUBLIC_ADDRESS':'127.0.0.1','GAME_FIRST_PORT':str(udp),'GAME_ROOM_LIMIT':'1'}
log=(out/'managed-service.log').open('w');server=subprocess.Popen(['node','matchmaking/server.mjs'],env=env,stdout=log,stderr=subprocess.STDOUT)
peers=[];handles=[]
def api(path,body=None):
 with urlopen(Request(url+path,data=json.dumps(body).encode() if body is not None else None,headers={'Content-Type':'application/json'}),timeout=25) as f:return json.load(f)
def state(label):
 try:return json.loads((work/(label+'-state.json')).read_text())
 except (OSError,ValueError):return {}
def wait(label,test):
 end=time.monotonic()+20
 while time.monotonic()<end:
  v=state(label)
  if test(v):return v
  time.sleep(.05)
 raise AssertionError((label,state(label)))
try:
 for _ in range(80):
  try:assert api('/health')['managed'];break
  except OSError:time.sleep(.1)
 else:raise AssertionError('Managed JS service did not listen')
 # First real game client uses normal room creation, including capability
 # discovery and JS allocation. It must become a client, never a fake host.
 h=(out/'managed-m0.log').open('w');handles.append(h)
 peers.append(subprocess.Popen([a.godot,'--headless','--path',a.project,'--script','scripts/backrooms_fps_session_checks.gd','--','--role=host','--label=m0','--slots=6','--map=3',f'--directory={url}',f'--output={work}'],stdout=h,stderr=subprocess.STDOUT))
 first=wait('m0',lambda x:x.get('active') and len(x.get('hp',{}))==1)
 assert first['mode']=='client' and not first['can_fire']
 room=api('/v1/rooms/'+first['room'])
 assert room['managed'] and room['max_players']==6 and room['map_id']==3
 for i in range(1,6):
  label=f'm{i}';h=(out/f'managed-{label}.log').open('w');handles.append(h)
  peers.append(subprocess.Popen([a.godot,'--headless','--path',a.project,'--script','scripts/backrooms_fps_session_checks.gd','--','--role=client',f'--label={label}',f'--directory={url}',f'--room={room["code"]}',f'--output={work}'],stdout=h,stderr=subprocess.STDOUT))
  v=wait(label,lambda x:x.get('active') and len(x.get('hp',{}))==i+1)
  assert v['map']==3
  if i==0:assert not v['can_fire'],'A dedicated server is never player 2'
  if i>=1:assert v['can_fire']
 for i in range(6):
  v=wait(f'm{i}',lambda x:len(x.get('hp',{}))==6)
  assert set(v['seats'].values())==set(range(1,7))
 time.sleep(1.2)
 assert api('/v1/rooms/'+room['code'])['players']==6
 for i in range(6):
  (work/f'm{i}-command.json').write_text(json.dumps({'op':'quit','serial':1}))
 for peer in peers:peer.wait(timeout=8);assert peer.returncode==0
 for i in range(6):
  text=(out/f'managed-m{i}.log').read_text();assert 'ERROR:' not in text and 'FAIL:' not in text,text
 print('FPS_JS_MANAGED_SIX_PLAYERS_PASS Node launches real Godot server, no server seat, one waits/two start, six seats/map sync, code lookup/counts')
finally:
 for peer in peers:
  if peer.poll() is None:peer.terminate();peer.wait(timeout=4)
 server.terminate();server.wait(timeout=4)
 for h in handles+[log]:h.close()
