extends RefCounted
## ENet peer timeouts for Join. A dial nobody answers fails within about 3 s
## (#348). After the server accepts the peer, a lost host is noticed within
## about 6 s, which still outlasts a server frame that places a castle.
## ENet's default limit of 32 lets a loaded round trip wait until the 30 s
## maximum, so a killed host can sit past the time a player should already
## be back on the main menu.


static func apply_dial_timeout(enet: ENetMultiplayerPeer) -> void:
	## Fail faster than ENet's default when nothing answers. Only for the dial.
	var peer := enet.get_peer(1)
	if peer != null:
		peer.set_timeout(8, 800, 3000)


static func ensure_relax_on_connected(mp: MultiplayerAPI, enet: ENetMultiplayerPeer) -> void:
	## Widen the dial timeout once connected_to_server fires, so a join that
	## spends a frame placing a castle is not dropped.
	if mp.connected_to_server.is_connected(_relax):
		return
	mp.connected_to_server.connect(_relax.bind(enet))


static func _relax(enet: ENetMultiplayerPeer) -> void:
	## limit, minimum, maximum. The maximum is the hard cap on a dead host.
	## The minimum still covers a multi-second server frame (#26 stress).
	var peer := enet.get_peer(1)
	if peer != null:
		peer.set_timeout(8, 4000, 5500)