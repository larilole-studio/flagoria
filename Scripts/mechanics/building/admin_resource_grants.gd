class_name AdminResourceGrants
extends Node
## The host authorizes grants. Each player keeps their own inventory.

const WOOD_GRANT := 100
const RESOURCE_TARGET := 999
const BUILD_RESOURCES: Array[StringName] = [Inventory.WOOD]

@export var inventory: Inventory


func is_admin(_peer_id: int) -> bool:
	return true


func can_grant() -> bool:
	var peer := multiplayer.multiplayer_peer
	return (
		peer != null
		and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
		and is_admin(multiplayer.get_unique_id())
	)


func grant(fill: bool) -> void:
	if not can_grant():
		return
	if multiplayer.is_server():
		_apply_grant(fill)
	else:
		request_grant.rpc_id(1, fill)


@rpc("any_peer", "reliable", "call_remote")
func request_grant(fill: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and sender > 1 and is_admin(sender):
		receive_grant.rpc_id(sender, fill)


@rpc("authority", "reliable", "call_remote")
func receive_grant(fill: bool) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		_apply_grant(fill)


func _apply_grant(fill: bool) -> void:
	if not fill:
		inventory.add(Inventory.WOOD, WOOD_GRANT)
		return
	for resource in BUILD_RESOURCES:
		var missing := RESOURCE_TARGET - inventory.count_of(resource)
		if missing > 0:
			inventory.add(resource, missing)
