extends "res://tests/helpers/probe_base.gd"
## Two peers stand 160 px apart on a fixed seed and throw on command.

const HOST_MARK := Vector2(8, 8)
const CLIENT_MARK := Vector2(168, 8)

var fired := false
var seen := {}
var warning_seen := false
var warning_radius := 0.0
var _shot_taken := false
var _shot_pending := false


func _run() -> void:
	var host := has_option("--host")
	var main := await open_game(host)
	if main == null:
		quit(1)
		return
	if host:
		if not host_saved_game(main, option("--save")).is_empty():
			quit(1)
			return
		park_mobs(main)
		var mobs := main.get_node("World/Mobs")
		mobs.set_physics_process(false)
		for mob in mobs.get_children():
			mob.set_physics_process(false)
		host_listening()
	else:
		await join_game(main)

	var world := main.get_node("World")
	var bombs := world.get_node("BombThrows") as BombThrows
	var mark := HOST_MARK if host else CLIENT_MARK
	var deadline := Time.get_ticks_msec() + 45000
	while game_active(main, deadline):
		var me := local_player(main) as CharacterBody2D
		if me != null and main.world_params != null:
			me.set_physics_process(false)
			me.position = mark
			me.get_node("regen_timer").stop()
			if not fired and FileAccess.file_exists(probe_out + ".fire"):
				fired = true
				var wheel := main.get_node("CanvasLayer1/ToolWheel") as ToolWheel
				wheel.select(ToolWheel.Tool.BOMB)
				var reach := Vector2(240, 0) if host else Vector2(-240, 0)
				me.attack_toward("", NAN, reach)
			for phase in BombThrows.Phase.values():
				if bombs.has_phase(phase):
					seen[phase] = true
			if bombs.has_phase(BombThrows.Phase.FUSE):
				warning_seen = true
				warning_radius = bombs.fuse_radius()
				if _shot_pending:
					_save_warning_shot(main)
				else:
					_shot_pending = true
		if snapshot_due(main):
			write_state(main)
		await process_frame
	finish(main, write_state.bind(main))


func write_state(main: Node) -> void:
	var health := {}
	for child in main.get_node("World").get_children():
		var player_health := child.get_node_or_null("Health") as PlayerHealth
		if player_health != null:
			health[str(child.name)] = player_health.health
	write_result(
		{
			"id": str(main.multiplayer.get_unique_id()),
			"health": health,
			"peers": peer_positions(main),
			"phases_seen": seen.size(),
			"warning_seen": warning_seen,
			"warning_radius": warning_radius,
			"errors": _errors.snapshot(),
		}
	)


func _save_warning_shot(main: Node) -> void:
	if _shot_taken or DisplayServer.get_name() == "headless":
		return
	var path := option("--shot")
	if path.is_empty():
		return
	var image := main.get_viewport().get_texture().get_image()
	if image != null:
		_shot_taken = true
		image.save_png(path)
