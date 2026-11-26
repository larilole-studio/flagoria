class_name TuningSync
extends Node
## The host owns the registry for the lifetime of a multiplayer match.

enum Edit { SET, STEP, RESET, RESET_ALL }

@export var admins: AdminResourceGrants

var _received_snapshot := false
var _local_overrides: Dictionary


func _ready() -> void:
	Tuning.events.changed.connect(_on_value_changed)


func _exit_tree() -> void:
	Tuning.events.changed.disconnect(_on_value_changed)
	if _received_snapshot:
		Tuning.replace_overrides(_local_overrides)
		_received_snapshot = false


func can_edit() -> bool:
	return admins.can_grant() and (multiplayer.is_server() or _received_snapshot)


func set_value(key: StringName, value: float) -> void:
	_edit(Edit.SET, key, value)


func step_value(key: StringName, delta: float) -> void:
	_edit(Edit.STEP, key, delta)


func reset(key: StringName) -> void:
	_edit(Edit.RESET, key)


func reset_all() -> void:
	_edit(Edit.RESET_ALL)


func sync_to_peer(peer_id: int) -> void:
	_receive_snapshot.rpc_id(peer_id, Tuning.overrides())


func _edit(operation: int, key: StringName = &"", value := 0.0) -> void:
	if not can_edit():
		return
	if multiplayer.is_server():
		_apply_edit(operation, key, value)
	else:
		_request_edit.rpc_id(1, operation, key, value)


@rpc("any_peer", "reliable", "call_remote")
func _request_edit(operation: int, key: StringName, value: float) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and sender > 1 and admins.is_admin(sender):
		_apply_edit(operation, key, value)


func _apply_edit(operation: int, key: StringName, value: float) -> void:
	match operation:
		Edit.SET:
			Tuning.set_value(key, value)
		Edit.STEP:
			Tuning.step_value(key, value)
		Edit.RESET:
			Tuning.reset(key)
		Edit.RESET_ALL:
			Tuning.reset_all()


func _on_value_changed(key: StringName) -> void:
	if (
		multiplayer.has_multiplayer_peer()
		and multiplayer.is_server()
		and not multiplayer.get_peers().is_empty()
	):
		_receive_value.rpc(key, Tuning.value(key))


@rpc("authority", "reliable", "call_remote")
func _receive_snapshot(snapshot: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		if not _received_snapshot:
			_local_overrides = Tuning.overrides()
			_received_snapshot = true
		Tuning.replace_overrides(snapshot)


@rpc("authority", "reliable", "call_remote")
func _receive_value(key: StringName, value: float) -> void:
	if multiplayer.get_remote_sender_id() == 1 and _received_snapshot:
		Tuning.set_value(key, value)
