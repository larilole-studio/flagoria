extends RefCounted
## ENet peer timeouts for Join. A dial nobody answers fails within about 3 s
## per attempt (#348). The attempt stops sending connect packets after about
## 1.5 s and then waits out the cap, so JoinDial re-dials until its
## budget instead of treating that gap as a dead host. After the server
## accepts the peer, a lost host is noticed within about 6 s
## (`set_timeout(8, 4000, 5500)`). That minimum is above a setup frame: the
## longest castle placement measured with four joins at once was 331 ms, and
## a 2 s stall after accept still left the peer up. ENet's default limit of
## 32 lets a loaded round trip wait until the 30 s maximum, so a killed host
## can sit past the time a player should already be back on the main menu.


static func apply_dial_timeout(enet: ENetMultiplayerPeer) -> void:
	## Fail faster than ENet's default when nothing answers. Only for the dial.
	var peer := enet.get_peer(1)
	if peer != null:
		peer.set_timeout(8, 800, 3000)


static var _relax_call := Callable()


static func ensure_relax_on_connected(mp: MultiplayerAPI, enet: ENetMultiplayerPeer) -> void:
	## Widen the dial timeout once connected_to_server fires, so a join that
	## spends a frame placing a castle is not dropped. Rebind when Join dials
	## again: the previous peer has been closed.
	if _relax_call.is_valid() and mp.connected_to_server.is_connected(_relax_call):
		mp.connected_to_server.disconnect(_relax_call)
	_relax_call = _relax.bind(enet)
	mp.connected_to_server.connect(_relax_call)


static func _relax(enet: ENetMultiplayerPeer) -> void:
	## limit, minimum, maximum. The maximum is the hard cap on a dead host.
	## The minimum still covers a multi-second server frame (#26 stress).
	var peer := enet.get_peer(1)
	if peer != null:
		peer.set_timeout(8, 4000, 5500)
