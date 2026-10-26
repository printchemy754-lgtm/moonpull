extends Node
## Wi-Fi race (same local network). The host creates a room; its code is the
## last two numbers of its IP address (e.g. "1.37" for 192.168.1.37).
## Others type the code to join. Up to 4 players. Android/desktop only (not web).

signal lobby_changed
signal race_started(level: int, seed: int)
signal state_received(id: int, z: float, water: float, holding: bool, alive: bool)
signal player_finished(id: int, time: float)
signal connection_failed(reason: String)
signal disconnected

const PORT := 47391
const MAX_PLAYERS := 4

var players := {}   # peer id -> {"name": String, "cfg": Dictionary}
var in_room := false
var is_host := false
var room_code := ""
var _join_timer: SceneTreeTimer


func supported() -> bool:
	return not OS.has_feature("web")


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): _fail("Could not reach that room."))
	multiplayer.server_disconnected.connect(func():
		leave()
		disconnected.emit())


static func local_ip() -> String:
	for a in IP.get_local_addresses():
		var ip: String = a
		if ip.begins_with("192.168.") or ip.begins_with("10.") or _is_172_private(ip):
			return ip
	return ""


static func _is_172_private(ip: String) -> bool:
	if not ip.begins_with("172."):
		return false
	var parts := ip.split(".")
	return parts.size() == 4 and int(parts[1]) >= 16 and int(parts[1]) <= 31


func host(pname: String, cfg: Dictionary) -> String:
	leave()
	var ip := local_ip()
	if ip == "":
		_fail("Connect to Wi-Fi first.")
		return ""
	# ENet is looked up dynamically: the web build has no ENet and must still compile.
	var peer = ClassDB.instantiate("ENetMultiplayerPeer") if ClassDB.class_exists("ENetMultiplayerPeer") else null
	if peer == null or peer.create_server(PORT, MAX_PLAYERS - 1) != OK:
		_fail("Could not create a room.")
		return ""
	multiplayer.multiplayer_peer = peer
	in_room = true
	is_host = true
	var parts := ip.split(".")
	room_code = "%s.%s" % [parts[2], parts[3]]
	players = {1: {"name": pname, "cfg": cfg}}
	lobby_changed.emit()
	return room_code


func join(code: String, pname: String, cfg: Dictionary) -> void:
	leave()
	var ip := local_ip()
	var c := code.strip_edges().split(".")
	if ip == "" or c.size() != 2 or not c[0].is_valid_int() or not c[1].is_valid_int():
		_fail("Type the code like 1.37" if ip != "" else "Connect to Wi-Fi first.")
		return
	var mine := ip.split(".")
	var target := "%s.%s.%s.%s" % [mine[0], mine[1], c[0], c[1]]
	var peer = ClassDB.instantiate("ENetMultiplayerPeer") if ClassDB.class_exists("ENetMultiplayerPeer") else null
	if peer == null or peer.create_client(target, PORT) != OK:
		_fail("Could not reach that room.")
		return
	multiplayer.multiplayer_peer = peer
	in_room = true
	is_host = false
	room_code = code
	players = {}
	set_meta("pending_profile", {"name": pname, "cfg": cfg})
	_join_timer = get_tree().create_timer(8.0)
	_join_timer.timeout.connect(func():
		if in_room and not is_host and players.is_empty():
			_fail("Room not found. Same Wi-Fi?"))


func leave() -> void:
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	in_room = false
	is_host = false
	room_code = ""
	players = {}


func my_id() -> int:
	return multiplayer.get_unique_id() if in_room else 1


func _fail(reason: String) -> void:
	leave()
	connection_failed.emit(reason)


func _on_connected() -> void:
	var p: Dictionary = get_meta("pending_profile", {})
	register.rpc_id(1, p.get("name", "Sailor"), p.get("cfg", {}))


func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	if players.has(id):
		players.erase(id)
		if is_host:
			lobby.rpc(players)
		lobby_changed.emit()


# ------------------------------------------------------------------ RPCs

@rpc("any_peer", "call_remote", "reliable")
func register(pname: String, cfg: Dictionary) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	if players.size() >= MAX_PLAYERS:
		return
	players[id] = {"name": pname.substr(0, 14), "cfg": cfg}
	lobby.rpc(players)
	lobby_changed.emit()


@rpc("authority", "call_remote", "reliable")
func lobby(list: Dictionary) -> void:
	players = list
	lobby_changed.emit()


func start(level: int, race_seed: int) -> void:
	if is_host:
		begin.rpc(level, race_seed)


@rpc("authority", "call_local", "reliable")
func begin(level: int, race_seed: int) -> void:
	race_started.emit(level, race_seed)


func send_state(z: float, water: float, holding: bool, alive: bool) -> void:
	if in_room:
		state.rpc(z, water, holding, alive)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func state(z: float, water: float, holding: bool, alive: bool) -> void:
	state_received.emit(multiplayer.get_remote_sender_id(), z, water, holding, alive)


func send_finished(time: float) -> void:
	if in_room:
		finished.rpc(time)


@rpc("any_peer", "call_remote", "reliable")
func finished(time: float) -> void:
	player_finished.emit(multiplayer.get_remote_sender_id(), time)
