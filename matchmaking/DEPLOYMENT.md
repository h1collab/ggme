# Public managed FACELESS 2 rooms (protocol 24)

Use a Linux VM with a public IPv4/IPv6 address, Node 22+, Godot 4.7.2 and the
built `app/` project from the **same SHA** as the APK. The project must include
imported licensed assets and `scripts/backrooms_dedicated.gd`. Import once with
`godot --headless --path /srv/faceless2/app --import`. Do not use GitHub Actions
as a permanent game server, or claim a directory is a game relay.

Run under an unprivileged service user (absolute executable/project paths):

```sh
GODOT_SERVER_BINARY=/usr/local/bin/godot \
GODOT_SERVER_PROJECT=/srv/faceless2/app \
GAME_PUBLIC_ADDRESS=YOUR_PUBLIC_IP \
GAME_FIRST_PORT=24800 GAME_ROOM_LIMIT=8 PORT=8787 \
node matchmaking/server.mjs
```

Expose **UDP 24800–24807** to players; expose HTTP 8787 only to a local trusted
HTTPS reverse proxy. Serve the directory at your real HTTPS domain with a valid
certificate. Leave `TRUST_PROXY=0` unless you exclusively bind/filter the app
behind a trusted proxy that overwrites forwarded IP headers. Put the HTTPS URL
in the game's room-service field. Players on separate networks then connect to
the public server, so their own routers need no incoming port mapping.

`GET /health` must return `protocol:24, managed:true`. `POST /v1/matches` takes
`{max_players:6,map_id:0,public:true}`. Maps are 0–3. The returned code resolves
through the normal room-code endpoint; no player IP needs typing. One player
waits; a second starts; at most six play. Public creation prefers available
public managed seats. Private rooms create a new process and are code-only.

Keys are per-room bearer capabilities, not player identities. HTTPS is required
outside localhost. Native ENet gameplay is currently unencrypted; this setup
provides authoritative rules, **not capture prevention**. Add your provider's
firewall, traffic/connection limits, resource isolation and monitoring before a
public launch. The committed tests use loopback and real processes; they do not
prove a deployment, carrier-network reachability, Android FPS or DDoS resistance.
