extends "res://tests/helpers/test_helpers.gd"
## Sand fringe overlay (Scripts/world/sky_islands.gd, Scripts/world/sand_fringe.gd).


func _test_sand_fringe() -> int:
	## Seed 42 default map: inland sand next to grass gets its fringe piece on
	## the fringe layer, layer 0 keeps the sand tile, and sand with no grass
	## around and grass cells get none. The fringe draws between the ground and
	## ground decor. Time cost: about 0.2 s in tools/verify.sh.
	print("-- test_sand_fringe")
	var fail := 0
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var world = scene.get_node("World/worldMap")
	world.apply_map_params(MapCli.params_for("default", "42")["params"])
	const NONE := Vector2i(-1, -1)
	# cell -> [layer 0 atlas, fringe atlas]
	var expected := {
		Vector2i(-31, -53): [TileCatalog.SAND, Vector2i(0, 14)],  # mask 0, grass all round
		Vector2i(-38, -68): [TileCatalog.SAND, Vector2i(12, 14)],  # mask 31, grass to the W
		Vector2i(65, -32): [TileCatalog.SAND, NONE],  # sand all round
	}
	for cell in expected:
		world.generate_chunk(world.map_to_local(cell))
		var ground: Vector2i = world.get_cell_atlas_coords(0, cell)
		var fringe: Vector2i = world.get_cell_atlas_coords(SkyIslands.FRINGE_LAYER, cell)
		if ground != expected[cell][0] or fringe != expected[cell][1]:
			printerr(
				(
					"FAIL sand_fringe: %s ground %s fringe %s, want %s"
					% [cell, ground, fringe, expected[cell]]
				)
			)
			fail += 1
	var grass := Vector2i(-30, -53)
	if world.get_cell_source_id(SkyIslands.FRINGE_LAYER, grass) != -1:
		printerr("FAIL sand_fringe: grass cell %s has a fringe" % grass)
		fail += 1
	var fringe_z: int = world.get_layer_z_index(SkyIslands.FRINGE_LAYER)
	if (
		fringe_z != world.get_layer_z_index(0)
		or fringe_z >= world.get_layer_z_index(world.GROUND_DECOR_LAYER)
	):
		printerr("FAIL sand_fringe: fringe layer z %s is not ground z under decor" % fringe_z)
		fail += 1
	scene.queue_free()
	if fail == 0:
		print("PASS test_sand_fringe")
	return fail
