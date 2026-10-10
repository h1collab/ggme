/**
 * Faceless 2 small JavaScript lobby/signaling directory (Node 22, zero dependencies).
 * Room registration and lookup ONLY. Actual gameplay packets remain Godot ENet/UDP.
 * A reachable UDP host endpoint / router mapping is still required across the Internet.
 * Do not mistake room discovery for WebRTC or automatic NAT traversal.
 * Rooms live in memory and expire unless the host heartbeats; deploy behind HTTPS.
 */
import http from 'node:http';
import { randomBytes, timingSafeEqual } from 'node:crypto';
import { fileURLToPath } from 'node:url';

const CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const DEFAULT_TTL = 45000;
const maxBytes = 4096;
function issueCode() {
  const bytes = randomBytes(8);
  return [...bytes].map(x => CODE_CHARS[x % CODE_CHARS.length]).join('');
}
function normalizeAddress(address) {
  let result = String(address || '').replace(/^::ffff:/, '').replace(/^\[/, '').replace(/\]$/, '');
  return result === '::1' ? '127.0.0.1' : result;
}
function reply(res, status, body) {
  const data = JSON.stringify(body);
  res.writeHead(status, {'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store', 'X-Content-Type-Options':'nosniff'});
  res.end(data);
}
function validToken(a,b) {
  const left = Buffer.from(a || ''), right = Buffer.from(b || '');
  return left.length === right.length && timingSafeEqual(left,right);
}
export function createLobbyServer({ttlMs = DEFAULT_TTL, trustProxy = false, clock = () => Date.now()} = {}) {
  const rooms = new Map();
  const rates = new Map();
  function gc() {for (const [code,room] of rooms) if (room.expires <= clock()) rooms.delete(code);}
  function clientAddress(req) {
    // Forwarded IPs are trusted ONLY when this server is behind a verified proxy.
    const fromProxy = trustProxy ? req.headers['x-forwarded-for']?.split(',')[0]?.trim() : null;
    return normalizeAddress(fromProxy || req.socket.remoteAddress);
  }
  async function payload(req) {
    let raw = '';
    for await (const part of req) {
      raw += part;
      if (raw.length > maxBytes) throw Object.assign(Error('body too large'),{status:413});
    }
    try {return JSON.parse(raw || '{}');} catch {throw Object.assign(Error('invalid json'), {status:400});}
  }
  function visible(room) {return {code:room.code,name:room.name,players:room.players,max_players:room.max_players,public:room.public};}
  const server = http.createServer(async (req,res) => {
    gc();
    const path = new URL(req.url || '/', 'http://lobby.invalid').pathname;
    const address = clientAddress(req);
    const window = Math.floor(clock()/60000), previous = rates.get(address);
    const count = previous?.window === window ? previous.count + 1 : 1;
    rates.set(address,{window,count});
    if(count > 140) return reply(res,429,{error:'rate limit'});
    if(req.method === 'GET' && path === '/health') return reply(res,200,{ok:true,service:'faceless2-directory',protocol:16});
    if(req.method === 'GET' && path === '/v1/rooms') {
      return reply(res,200,{rooms:[...rooms.values()].filter(r => r.public).slice(0,64).map(visible)});
    }
    if(req.method === 'POST' && path === '/v1/rooms') {
      try {
        const p=await payload(req);
        const port=Number(p.port), max=Number(p.max_players);
        if (!Number.isInteger(port) || port<1024 || port>65535 || !Number.isInteger(max) || max<2 || max>4 || typeof p.public!=='boolean')
          return reply(res,400,{error:'invalid capacity, visibility, or UDP port'});
        if([...rooms.values()].filter(r => r.address === address).length>=8) return reply(res,429,{error:'too many rooms'});
        let code = issueCode(); while (rooms.has(code)) code=issueCode();
        const token=randomBytes(24).toString('hex');
        const key=randomBytes(12).toString('hex');
        const room={code,name:String(p.name || 'Faceless 2').trim().slice(0,48),address,port,public:p.public,max_players:max,players:1,token,key,expires:clock()+ttlMs};
        rooms.set(code,room);
        return reply(res,201,{code,owner_token:token,key,expires_in_ms:ttlMs,...visible(room)});
      }catch(e){return reply(res,e.status||500,{error:e.message});}
    }
    const m = /^\/v1\/rooms\/([A-Z2-9]{8})(?:\/(heartbeat))?$/.exec(path);
    if(!m) return reply(res,404,{error:'not found'});
    const room = rooms.get(m[1]);
    if(!room) return reply(res,404,{error:'room missing or expired'});
    if(req.method === 'GET' && !m[2]) {
      // Even a private room can be resolved by someone knowing its non-guessable code.
      return reply(res,200,{...visible(room),public:room.public,address:room.address,port:room.port,key:room.key});
    }
    if(req.method === 'POST' && m[2] === 'heartbeat') {
      try {
        const p=await payload(req);
        if(!validToken(p.owner_token,room.token)) return reply(res,403,{error:'not room owner'});
        if(Number.isInteger(p.players) && p.players>=1 && p.players<=room.max_players) room.players=p.players;
        room.expires=clock()+ttlMs;
        return reply(res,200,{ok:true,players:room.players,expires_in_ms:ttlMs});
      }catch(e){return reply(res,e.status||500,{error:e.message});}
    }
    if(req.method === 'DELETE' && !m[2]) {
      try{
        const p=await payload(req);
        if(!validToken(p.owner_token,room.token)) return reply(res,403,{error:'not room owner'});
        rooms.delete(room.code);
        return reply(res,200,{ok:true});
      }catch(e){return reply(res,e.status||500,{error:e.message});}
    }
    return reply(res,405,{error:'method not allowed'});
  });
  return {server, rooms, cleanup:gc};
}
if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const port = Number(process.env.PORT || 8787);
  const {server}=createLobbyServer({trustProxy:process.env.TRUST_PROXY === '1'});
  server.listen(port, '0.0.0.0', () => console.log(`FAC2 LOBBY: http://0.0.0.0:${port} — HTTPS reverse proxy required for production`));
}
