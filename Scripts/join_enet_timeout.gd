extends RefCounted
## ENet peer timeouts for Join: a short floor while dialing (#348), then
## ENet's usual defaults once the server accepts the peer so a busy server
## frame cannot drop a joiner (#26 stress).


static func apply_dial_timeout(enet: ENetMultiplayerPeer) -> void:
	## Fail faster than ENet's default when nothing answers. Only for the dial.
	var peer := enet.get_peer(1)
	if peer != null:
		peer.set_timeout(8, 800, 3000)


static func ensure_relax_on_connected(mp: MultiplayerAPI, enet: ENetMultiplayerPeer) -> void:
	## Restore ENet defaults after connected_to_server so a join that spends a
	## frame placing a castle is not dropped.
	if mp.connected_to_server.is_connected(_relax):
		return
	mp.connected_to_server.connect(_relax.bind(enet))


static func _relax(enet: ENetMultiplayerPeer) -> void:
	var peer := enet.get_peer(1)
	if peer != null:
		peer.set_timeout(32, 5000, 30000)