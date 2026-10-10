extends Node

# Room discovery: local UDP announcements work without infrastructure on most LANs.
# Optional JavaScript directory provides room codes and public/private listings
# over HTTPS. Transport remains ENet/UDP; a reachable UDP host is necessary.
signal rooms_changed(rooms: Array)
signal room_created(code: String)
signal room_error(message: String)
const DISCOVERY_PORT := 24717
const DEFAULT_GAME_PORT := 24711
const CODE_ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const VERSION := 16
var game: Node
var client: HTTPRequest
var receiver: PacketPeerUDP
var broadcaster: PacketPeerUDP
var directory_url := ""
var game_port := DEFAULT_GAME_PORT
var room_code := ""
var owner_token := ""
var room_key := ""
var room_public := true
var room_name := "Faceless 2"
var max_players := 4
var state := "idle"
var operation := ""
var timer := 0.0
var heartbeat_clock := 0.0
var pending_code := ""
var advertised: Dictionary = {}
var remote_public: Array = []

func _ready() -> void:
	name = "RoomDiscovery"
	client = HTTPRequest.new()
	client.timeout = 7.0
	add_child(client)
	client.request_completed.connect(_http_complete)
	receiver = PacketPeerUDP.new()
	var err := receiver.bind(DISCOVERY_PORT, "0.0.0.0")
	if err != OK: push_warning("LAN discovery listener unavailable; online directory may still work")
	broadcaster = PacketPeerUDP.new()
	broadcaster.set_broadcast_enabled(true)
	broadcaster.set_dest_address("255.255.255.255", DISCOVERY_PORT)

func configure(url: String) -> void:
	# HTTPS only outside explicit localhost development mode.
	var normalized := url.strip_edges().trim_suffix("/")
	if normalized.is_empty() or normalized.begins_with("https://") or normalized.begins_with("http://127.0.0.1:"):
		directory_url = normalized
	else:
		room_error.emit("公共房间服务需要 HTTPS；局域网房间仍可使用")

func _new_code() -> String:
	var result := ""
	for value in Crypto.new().generate_random_bytes(8):
		result += CODE_ALPHABET[int(value) % CODE_ALPHABET.length()]
	return result

func create_room(public_room: bool, slots: int, title: String = "") -> void:
	if game.net.mode != "solo": game.net.leave()
	room_public = public_room
	max_players = clampi(slots, 2, 4)
	room_name = title.strip_edges().substr(0, 40) if not title.strip_edges().is_empty() else "Faceless 2 / 后室调查"
	room_code = ""
	owner_token = ""
	room_key = ""
	if not directory_url.is_empty():
		_send("create", HTTPClient.METHOD_POST, "/v1/rooms", {"name":room_name,"port":game_port,"public":room_public,"max_players":max_players})
	else:
		_finish_create(_new_code(), _new_code())

func _finish_create(code: String, key: String) -> void:
	# ENet.host() internally calls leave(); preserve the just-issued JS owner
	# capability while it clears a previously active room.
	var issued_token := owner_token
	var result: Error = game.net.host(game_port, key, true, max_players)
	owner_token = issued_token
	if result != OK:
		room_error.emit("无法打开 UDP 房间端口；请稍后重试")
		return
	room_code = code
	room_key = key
	state = "host"
	game.start_shift(0)
	room_created.emit(code)

func discover() -> void:
	_prune()
	rooms_changed.emit(public_rooms())
	if not directory_url.is_empty(): _send("list", HTTPClient.METHOD_GET, "/v1/rooms")

func public_rooms() -> Array:
	var result: Array = []
	for code in advertised:
		var item: Dictionary = advertised[code]
		if bool(item.get("public", false)): result.append(item.duplicate())
	for item in remote_public:
		var dup := false
		for local in result:
			if local.get("code") == item.get("code"): dup = true
		if not dup: result.append(item.duplicate())
	return result

func join_code(input_code: String) -> void:
	var code := input_code.strip_edges().to_upper().replace("-", "")
	if code.length() != 8:
		room_error.emit("请输入 8 位房间号")
		return
	pending_code = code
	if advertised.has(code):
		var target: Dictionary = advertised[code]
		_join_endpoint(target)
	elif not directory_url.is_empty():
		_send("resolve", HTTPClient.METHOD_GET, "/v1/rooms/" + code)
	else:
		room_error.emit("局域网尚未发现此房间；跨网络需要部署 JS 房间服务")

func _join_endpoint(target: Dictionary) -> void:
	if int(target.get("players", 1)) >= int(target.get("max_players", 4)):
		room_error.emit("房间人数已满")
		return
	var result: Error = game.net.join(String(target.get("address", "")), int(target.get("port", DEFAULT_GAME_PORT)), String(target.get("key", "")))
	if result != OK: room_error.emit("无法连接房主的 UDP 地址；检查端口映射或网络")
	else:
		room_code = String(target.get("code", pending_code))
		state = "client"

func _send(kind: String, method: HTTPClient.Method, path: String, content: Dictionary = {}) -> void:
	if directory_url.is_empty() or not is_instance_valid(client): return
	if client.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		if kind != "heartbeat": room_error.emit("房间服务正忙，稍后重试")
		return
	operation = kind
	var body := JSON.stringify(content) if method != HTTPClient.METHOD_GET else ""
	var error: Error = client.request(directory_url + path, ["Content-Type: application/json"], method, body)
	if error != OK and kind != "heartbeat": room_error.emit("房间服务不可达，局域网模式仍可用")

func _http_complete(_result: int, status_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var op := operation
	operation = ""
	var decoded: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(decoded) != TYPE_DICTIONARY: decoded = {}
	var response: Dictionary = decoded
	if status_code < 200 or status_code >= 300:
		if op != "heartbeat": room_error.emit("房间服务：%s（HTTP %d）" % [String(response.get("error", "无法连接")), status_code])
		return
	match op:
		"create":
			owner_token = String(response.get("owner_token", ""))
			_finish_create(String(response.get("code", "")), String(response.get("key", "")))
		"list":
			remote_public = response.get("rooms", [])
			rooms_changed.emit(public_rooms())
		"resolve": _join_endpoint(response)

func _process(delta: float) -> void:
	timer += delta
	if receiver != null:
		var max_packets := 8
		while receiver.get_available_packet_count() > 0 and max_packets > 0:
			max_packets -= 1
			var msg: Variant = JSON.parse_string(receiver.get_packet().get_string_from_utf8())
			if typeof(msg) != TYPE_DICTIONARY: continue
			if int(msg.get("protocol", -1)) != VERSION: continue
			var code := String(msg.get("code", ""))
			if code.length() != 8: continue
			if code == room_code and state == "host": continue
			msg["address"] = receiver.get_packet_ip() # never trust a spoofed payload IP
			msg["last_seen"] = Time.get_ticks_msec()
			advertised[code] = msg
	if timer >= 2.0:
		timer = 0
		_prune()
		if state == "host" and game.net.mode == "host" and not room_code.is_empty():
			# Both public and private rooms broadcast; private listings are hidden
			# from UI, but a local peer knowing the code can resolve it.
			var info := {"protocol":VERSION,"code":room_code,"key":room_key,"port":game.net.port,"name":room_name,"max_players":max_players,"players":game.net.members.size(),"public":room_public}
			broadcaster.put_packet(JSON.stringify(info).to_utf8_buffer())
		if state == "host" and game.net.mode != "host": state = "idle"
		if is_instance_valid(game.ui) and game.ui.panel_kind == "lobby":
			rooms_changed.emit(public_rooms())
	heartbeat_clock += delta
	if state == "host" and heartbeat_clock > 12.0 and not owner_token.is_empty():
		heartbeat_clock = 0
		_send("heartbeat", HTTPClient.METHOD_POST, "/v1/rooms/%s/heartbeat" % room_code, {"owner_token":owner_token,"players":game.net.members.size()})

func _prune() -> void:
	for code in advertised.keys():
		if Time.get_ticks_msec() - int(advertised[code].get("last_seen", 0)) > 11000: advertised.erase(code)

func leave_room() -> void:
	if state == "host" and not owner_token.is_empty():
		_send("delete", HTTPClient.METHOD_DELETE, "/v1/rooms/%s" % room_code, {"owner_token":owner_token})
	state = "idle"
	room_code = ""
	owner_token = ""
	room_key = ""

func _exit_tree() -> void:
	if receiver != null: receiver.close()
	if broadcaster != null: broadcaster.close()
