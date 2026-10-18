/** Fixed-command supervisor for authoritative native UDP rooms. Never accepts a
 * command, path, executable or address from a player. Deploy behind HTTPS on a
 * public UDP-capable machine. No assumption that JS alone traverses NAT. */
import {spawn} from 'node:child_process';
import {randomBytes} from 'node:crypto';
import path from 'node:path';
export function createManagedRooms({godot,project,address,firstPort=24800,roomLimit=8,startTimeout=15000,spawnProcess=spawn}={}) {
  if(!godot || !project || !address || !path.isAbsolute(project) || !path.isAbsolute(godot)) throw Error('Managed rooms require absolute Godot/project paths and public address');
  const active=new Map(); let stopping=false;
  async function allocate({slots,map,name,public:listed}) {
    if(stopping || active.size>=roomLimit) throw Error('Managed server capacity reached');
    let port=firstPort; while([...active.values()].some(r=>r.port===port))port++;
    const id=randomBytes(16).toString('hex');
    const key=randomBytes(12).toString('hex');
    const room={id,key,port,address,max_players:slots,map_id:map,name,public:listed,players:0,ready:false};
    active.set(id,room);
    const child=spawnProcess(godot,['--headless','--path',project,'--script','scripts/backrooms_dedicated.gd','--',`--port=${port}`,`--slots=${slots}`,`--map=${map}`],{stdio:['pipe','pipe','ignore'],env:{...process.env}});
    room.child=child;
    child.stdin.end(key+'\n'); // room credential never in process args or logs
    return await new Promise((resolve,reject)=>{
      let pending='',settled=false;
      const finish=(error)=>{if(settled)return;settled=true;clearTimeout(timer);if(error){active.delete(id);child.kill();reject(error);}else resolve(room);};
      const timer=setTimeout(()=>finish(Error('Native room startup timed out')),startTimeout);
      child.on('error',()=>finish(Error('Native room could not start')));
      child.on('exit',()=>{active.delete(id);finish(Error('Native room exited'));});
      child.stdout.setEncoding('utf8');
      child.stdout.on('data',chunk=>{
        pending+=chunk;if(pending.length>16384){finish(Error('Native room output limit'));return;}
        let at;while((at=pending.indexOf('\n'))>=0){
          const line=pending.slice(0,at).trim();pending=pending.slice(at+1);
          if(line==='FAC2_DEDICATED_READY'){room.ready=true;finish();}
          if(line.startsWith('FAC2_DEDICATED_STATE '))try{
            const state=JSON.parse(line.slice(21));
            if(Number.isInteger(state.players)&&state.players>=0&&state.players<=slots)room.players=state.players;
          }catch{}
        }
      });
    });
  }
  function close(){stopping=true;for(const room of active.values())room.child?.kill();active.clear();}
  return {allocate,active,close};
}
