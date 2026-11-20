extends "res://tests/helpers/probe_base.gd"
## One peer of the dedicated cut-and-hit round (tests/net/test_dedicated_play_round.gd).
##
##   -- --port=N --out=PATH --cells=x,y [--mob=mob_N] [--rate=F] --dedicated --save=SAVE
##       dedicated server, no local player. --rate is the mob rate the plan used.
##   -- --port=N --out=PATH --cells=x,y [--mob=mob_N]
##       client. PATH.cut lists cells to cut through Interaction._cut.
##       PATH.hit asks this client to swing at --mob until it is gone.
##
## Writes a JSON snapshot about every 100 ms. Quits when PATH.stop exists.




func _run() -> void:
	var save := option("--save")
	var dedicated := has_option("--dedicated")
	var rate := option("--rate", "-1").to_float()
	var mob_name := option("--mob")
	var listed := _parse_cells(option("--cells"))
	if dedicated and save == "":
		printerr("dedicated_play_probe: needs --port=N --out=PATH, and --save=PATH with --dedicated")
		quit(1)
		return
	var main = await open_game(dedicated)
	if main == null:
		printerr("dedicated_play_probe: needs --port=N --out=PATH, and --save=PATH with --dedicated")
		quit(1)
		return
	if dedicated:
		var loaded: Dictionary = MapSave.load_map(save)
		if rate >= 0.0:
			root.get_node("GameSettings").set_mob_rate(rate, false)
		if loaded["error"] != "" or host_dedicated(main, loaded["params"]) != OK:
			printerr("dedicated_play_probe: could not host %s: %s" % [save, loaded["error"]])
			quit(1)
			return
		host_listening()
	else:
		await join_game(main)
	var world = main.get_node("World/worldMap")
	var interaction: Interaction = main.get_node("World/Interaction")
	var cut_done := {}
	var hitting := false
	var next_swing := 0
	var seen: Array[int] = []
	var watched_hp := -1
	var present := false
	var deadline := Time.get_ticks_msec() + 90000
	while game_active(main, deadline):
		var me: Node2D = main.get_node_or_null("World/" + str(main.multiplayer.get_unique_id()))
		if not dedicated and me and main.world_params != null and FileAccess.file_exists(probe_out + ".cut"):
			for cell in _parse_cells(FileAccess.get_file_as_string(probe_out + ".cut")):
				if cut_done.has(cell):
					continue
				me.global_position = interaction.cell_center(cell) + Vector2(12, 0)
				var wait := Time.get_ticks_msec() + 300
				while Time.get_ticks_msec() < wait:
					await process_frame
				cut_done[cell] = interaction._cut(cell)
		var mob: Mob = null
		if mob_name != "":
			mob = main.get_node_or_null("World/Mobs/" + mob_name) as Mob
		if mob:
			present = true
			watched_hp = mob.hp
			if not seen.has(mob.state):
				seen.append(mob.state)
		elif present:
			present = false
		if not dedicated and me and FileAccess.file_exists(probe_out + ".hit") and mob:
			hitting = true
			_sword_on(me, mob)
			if Time.get_ticks_msec() >= next_swing and not me.isAttacking:
				me.attack_animation.rpc()
				next_swing = Time.get_ticks_msec() + 600
		if snapshot_due(main):
			_write(main, world, listed, me, dedicated, mob_name, seen, watched_hp, present, hitting)
		await process_frame
	finish(main, func() -> void:
		_write(main, world, listed, local_player(main), dedicated, mob_name, seen, watched_hp, present, hitting))


static func _parse_cells(text: String) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for part in text.strip_edges().split(";", false):
		var cell = WorldSave.parse_cell(part)
		if cell != null:
			cells.append(cell)
	return cells


static func _sword_on(player: Node2D, mob: Mob) -> void:
	var blade: Node2D = player.get_node("weapon/sword/CollisionShape2D")
	player.position += mob.hurt_box.global_position - blade.global_position
	player.velocity = Vector2.ZERO


func _write(main, world, listed: Array[Vector2i], me: Node2D, dedicated: bool,
		mob_name: String, seen: Array[int], watched_hp: int, present: bool, hitting: bool) -> void:
	var players: Array[String] = []
	for node in main.get_node("World").get_children():
		if node is CharacterBody2D and str(node.name).is_valid_int():
			players.append(str(node.name))
	players.sort()
	var cells := {}
	if main.world_params != null:
		for cell in listed:
			var decor: Vector2i = world.get_cell_atlas_coords(world.GROUND_DECOR_LAYER, cell)
			var plant: Vector2i = world.get_cell_atlas_coords(1, cell)
			cells[WorldSave.cell_key(cell)] = {
				"plant": [plant.x, plant.y],
				"decor": [decor.x, decor.y],
				"clear": world.is_clear_ground(cell),
			}
	var cuts: Array[String] = []
	var changed: Dictionary = world.cut_changes()
	for chunk in changed:
		for key in changed[chunk]:
			cuts.append(key)
	cuts.sort()
	var wood := 0
	if not dedicated:
		wood = main.get_node("Inventory").count_of(Inventory.WOOD)
	write_result({
		"id": str(main.multiplayer.get_unique_id()),
		"ready": main.world_params != null and (dedicated or me != null),
		"dedicated": dedicated,
		"players": players,
		"cuts": cuts,
		"cells": cells,
		"wood": wood,
		"mob": mob_name,
		"mob_states": seen,
		"mob_hp": watched_hp,
		"mob_present": present,
		"hitting": hitting,
		"errors": _errors.snapshot(),
	})
