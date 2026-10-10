import test from 'node:test';
import assert from 'node:assert/strict';
import {once} from 'node:events';
import {createLobbyServer} from './server.mjs';

async function setup(ttlMs=45000) {
  let now=100000;
  const app=createLobbyServer({ttlMs,clock:()=>now});
  app.server.listen(0,'127.0.0.1');await once(app.server,'listening');
  const url=`http://127.0.0.1:${app.server.address().port}`;
  const api=async(method,path,p) => {const r=await fetch(url+path,{method,headers:{'content-type':'application/json'},body:p===undefined?undefined:JSON.stringify(p)});return {status:r.status,body:await r.json()};};
  return {app,api,advance:n=>now+=n,close:()=>app.server.close()};
}
test('public rooms visible; private rooms code-only; owner-only heartbeat and delete; expiry', async() => {
 const a=await setup(5000);
 try{
   const p=await a.api('POST','/v1/rooms',{name:'North corridor',port:24711,max_players:2,public:true});
   const q=await a.api('POST','/v1/rooms',{name:'Secrets',port:24712,max_players:4,public:false});
   assert.equal(p.status,201);assert.equal(q.status,201);
   assert.match(p.body.code,/^[A-Z2-9]{8}$/);
   assert.notEqual(p.body.code,q.body.code);
   let list=(await a.api('GET','/v1/rooms')).body.rooms;
   assert.equal(list.length,1);assert.equal(list[0].max_players,2);
   assert.equal(list[0].address,undefined);
   const lookup=await a.api('GET','/v1/rooms/'+q.body.code);
   assert.equal(lookup.status,200);assert.equal(lookup.body.public,false);assert.equal(lookup.body.address,'127.0.0.1');
   assert.equal((await a.api('POST','/v1/rooms/'+p.body.code+'/heartbeat',{owner_token:'wrong'})).status,403);
   assert.equal((await a.api('POST','/v1/rooms/'+p.body.code+'/heartbeat',{owner_token:p.body.owner_token,players:2})).body.players,2);
   a.advance(5500);
   assert.equal((await a.api('GET','/v1/rooms')).body.rooms.length,0);
   assert.equal((await a.api('GET','/v1/rooms/'+q.body.code)).status,404);
   assert.equal((await a.api('DELETE','/v1/rooms/'+p.body.code,{owner_token:p.body.owner_token})).status,404);
 } finally {a.close();}
});
test('capacity and malformed rooms rejected; health and manual leave',async()=>{
 const a=await setup();try {
  const base={name:'Room',port:24711,max_players:4,public:true};
  assert.equal((await a.api('POST','/v1/rooms',{...base,max_players:5})).status,400);
  assert.equal((await a.api('POST','/v1/rooms',{...base,port:0})).status,400);
  assert.equal((await a.api('GET','/health')).body.protocol,16);
  const room=(await a.api('POST','/v1/rooms',base)).body;
  assert.equal((await a.api('DELETE',`/v1/rooms/${room.code}`,{owner_token:'not-owner'})).status,403);
  assert.equal((await a.api('DELETE',`/v1/rooms/${room.code}`,{owner_token:room.owner_token})).status,200);
  assert.equal((await a.api('GET','/v1/rooms')).body.rooms.length,0);
 }finally{a.close();}
});
