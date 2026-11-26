extends "res://tests/helpers/test_helpers.gd"

const MINE_WOOD := &"building.mine_wood"
const PLANK_WOOD := &"building.plank_wood"


func _test_tuning_save_round_trip() -> int:
	var scene := mount_main_scene()
	var map_gen := root.get_node("MapGen")
	var original_params: MapGenParams = map_gen.params
	var inputs := MapGenParams.make_defaults()
	inputs.ensure_seeds()
	scene.world_params = inputs
	Tuning.set_value(MINE_WOOD, 20)
	var saved: Dictionary = scene.get_node("CanvasLayer1/InGameMenu").save_world()
	var path: String = saved["path"]
	var doc: Dictionary = MapSave.read_document(path).get("data", {}) if path != "" else {}
	var stored: Dictionary = doc.get("world", {}).get("tuning", {})
	Tuning.set_value(MINE_WOOD, 15)
	Tuning.set_value(PLANK_WOOD, 4)
	var loaded: bool = (
		map_gen.load_map_inputs(path) == "" and map_gen.take_loaded_world(inputs) != null
	)
	var ok := (
		loaded and stored == {"building.mine_wood": 20.0} and BuildCosts.cost(BuildCosts.MINE) == 20
	)
	ok = ok and BuildCosts.cost(BuildCosts.PLANK) == 1
	if loaded:
		doc["world"]["tuning"] = {"unknown": 90, "building.mine_wood": 1000}
		var edited := FileAccess.open(path, FileAccess.WRITE)
		edited.store_string(JSON.stringify(doc, "", true, true))
		edited.close()
		ok = (
			map_gen.load_map_inputs(path) == ""
			and map_gen.take_loaded_world(map_gen.params) != null
			and BuildCosts.cost(BuildCosts.MINE) == 100
			and ok
		)
	Tuning.reset_all()
	map_gen.params = original_params
	if path != "":
		DirAccess.remove_absolute(path)
	scene.queue_free()
	await process_frame
	if not ok:
		printerr("FAIL tuning save: sparse overrides, world switch or invalid override handling")
	return 0 if ok else 1


func _test_tuning_save_legacy() -> int:
	var map_gen := root.get_node("MapGen")
	var original_params: MapGenParams = map_gen.params
	Tuning.set_value(MINE_WOOD, 20)
	var loaded: bool = map_gen.load_map_inputs("res://tests/fixtures/world_save_v1.json") == ""
	var ok: bool = (
		loaded
		and map_gen.take_loaded_world(map_gen.params) != null
		and BuildCosts.cost(BuildCosts.MINE) == 15
	)
	Tuning.set_value(MINE_WOOD, 20)
	ok = (
		map_gen.take_loaded_world(map_gen.params) == null
		and BuildCosts.cost(BuildCosts.MINE) == 15
		and ok
	)
	Tuning.reset_all()
	map_gen.params = original_params
	if not ok:
		printerr("FAIL tuning defaults: legacy saves and new worlds should use 15 wood")
	return 0 if ok else 1
