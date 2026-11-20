extends RefCounted
## Re-dials Join until the budget runs out.
## One ENet dial sends its last connect packet about 1.5 s in, then waits
## out the rest of the 3 s cap. A host that starts polling in that gap is
## still alive (a 1.2 s stall before listen connects; 1.6 s does not).
## Re-dial every 1 s for 6 s, which still connects through a 4 s stall, and
## an unanswered join still returns inside the 8 s menu check.

const JoinEnetTimeout = preload("res://Scripts/net/join_enet_timeout.gd")

const BUDGET_MS := 6000
const REDIAL_MS := 1000

var until := 0
var redial_at := 0
var closing := false


func begin(main: Node) -> void:
	var now := Time.get_ticks_msec()
	until = now + BUDGET_MS
	redial_at = now + REDIAL_MS
	open(main)


func open(main: Node) -> void:
	## A fresh peer each attempt: close() then create_client on the same
	## object fails a second Join after a timeout.
	var previous := main.enet_peer as ENetMultiplayerPeer
	closing = true
	if previous != null:
		previous.close()
	closing = false
	var peer := ENetMultiplayerPeer.new()
	main.enet_peer = peer
	var err := peer.create_client(main._join_host, main._join_port)
	if err != OK:
		until = 0
		main._on_join_failed()
		return
	var mp := main.multiplayer as MultiplayerAPI
	mp.multiplayer_peer = peer
	_ensure_signals(main, mp, peer)
	JoinEnetTimeout.apply_dial_timeout(peer)
	var world = main.get_node("World/worldMap")
	world.player_spawned = true


func _ensure_signals(main: Node, mp: MultiplayerAPI, peer: ENetMultiplayerPeer) -> void:
	if not mp.connected_to_server.is_connected(main._on_join_connected):
		mp.connected_to_server.connect(main._on_join_connected)
	if not mp.connection_failed.is_connected(main._on_connection_failed):
		mp.connection_failed.connect(main._on_connection_failed)
	if not mp.server_disconnected.is_connected(main._on_server_disconnected):
		mp.server_disconnected.connect(main._on_server_disconnected)
	JoinEnetTimeout.ensure_relax_on_connected(mp, peer)


func on_connected() -> void:
	until = 0


func service(main: Node) -> void:
	if until == 0:
		return
	var mp := main.multiplayer as MultiplayerAPI
	var peer := mp.multiplayer_peer
	if peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		until = 0
		return
	var now := Time.get_ticks_msec()
	if now >= until:
		until = 0
		main._on_join_failed()
		return
	if now >= redial_at:
		redial_at = now + REDIAL_MS
		open(main)


func defers_failure() -> bool:
	## The budget owns the retry. A cap that fires on a peer we already
	## replaced must not end the join early.
	return closing or until != 0


func abandon() -> void:
	until = 0


func set_closing(value: bool) -> void:
	closing = value
