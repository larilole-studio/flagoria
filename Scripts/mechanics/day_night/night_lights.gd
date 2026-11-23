class_name NightLights
extends Node
## Local night pools on players and lit buildings (#560).
##
## One gold PointLight2D per player, castle, tower and guard post. Energy is
## the docs/day_night.json night value times a 0–1 factor: 0 through the day
## hold, smoothstep across the dusk minute, 1 through the night hold, and
## back down across the dawn minute. Each peer builds the pools from the
## players and placements it already has, so nothing is replicated.
##
## A headless host creates no lights and runs no tick. A display peer writes
## energy only on a coarse timer, and only when the value changed, so the
## canvas is not dirtied every frame.

const TEXTURE_PATH := "res://art/day_night/light_radial_smooth_128.png"
const COLOR_HEX := "#f2b632"
const CAP := 16
## Same cadence as the clock sync. Dusk and dawn ease over 15 seconds, so a
## quarter-second step still reads as a fade.
const COARSE_SECONDS := 0.25
## Walk frame is 16 px, centred on the sprite at (0, -8). The pool sits on
## the body, not the feet.
const BODY_OFFSET := Vector2(0, -8)

const SCALE := {
	"player": 1.0,
	"castle": 1.5,
	"tower": 0.875,
	"guard_post": 0.75,
}
const ENERGY := {
	"player": 1.1,
	"castle": 1.2,
	"tower": 0.9,
	"guard_post": 0.75,
}
## Structure file name -> light kind. Barracks and other files are dark.
const KIND := {
	"castle": "castle",
	"tower_wood": "tower",
	"guard_post": "guard_post",
}

var _draws := false
var _texture: Texture2D
var _pool: Dictionary = {}
var _defs: Dictionary = {}


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	# Headless hosts that dirty the canvas from _process stop polling the
	# network. Create nothing and schedule nothing there.
	if DisplayServer.get_name() == "headless":
		return
	_draws = true
	var timer := Timer.new()
	timer.name = "Coarse"
	timer.wait_time = COARSE_SECONDS
	timer.timeout.connect(_refresh)
	add_child(timer)
	timer.start()
	call_deferred("_refresh")


func active_lights() -> Array[PointLight2D]:
	var out: Array[PointLight2D] = []
	for id in _pool:
		var light: PointLight2D = _pool[id]
		if is_instance_valid(light) and light.energy > 0.0:
			out.append(light)
	return out


func active_count() -> int:
	return active_lights().size()


static func light_color() -> Color:
	return Color.html(COLOR_HEX)


static func kind_of(structure_name: String) -> String:
	if not KIND.has(structure_name):
		return ""
	return str(KIND[structure_name])


static func night_factor(seconds: float) -> float:
	## 0 through the day hold, smoothstep across dusk, 1 through the night
	## hold, smoothstep back to 0 across dawn.
	var t := DayNight.cycle_wrap(seconds)
	var day_end := float(DayNight.PHASE_END[0])
	var dusk_end := float(DayNight.PHASE_END[1])
	var night_end := float(DayNight.PHASE_END[2])
	if t < day_end:
		return 0.0
	if t < dusk_end:
		var span := dusk_end - day_end
		return DayNight.cycle_ease((t - day_end) / span) if span > 0.0 else 1.0
	if t < night_end:
		return 1.0
	var dawn := DayNight.CYCLE_SECONDS - night_end
	if dawn <= 0.0:
		return 0.0
	return 1.0 - DayNight.cycle_ease((t - night_end) / dawn)


static func energy_at(kind: String, seconds: float, enabled := true) -> float:
	if not enabled or not ENERGY.has(kind):
		return 0.0
	return float(ENERGY[kind]) * night_factor(seconds)


static func pick_ids(sources: Array, camera: Vector2, cap: int) -> Array[String]:
	## Local (pinned) sources first, then the nearest others, up to `cap`.
	## Equal distances break by id so the set is deterministic.
	var pinned: Array[String] = []
	var rest: Array = []
	for src in sources:
		if typeof(src) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = src
		if bool(row.get("pinned", false)):
			pinned.append(str(row["id"]))
		else:
			rest.append(row)
	rest.sort_custom(
		func(a, b) -> bool:
			var da := (a["pos"] as Vector2).distance_squared_to(camera)
			var db := (b["pos"] as Vector2).distance_squared_to(camera)
			if not is_equal_approx(da, db):
				return da < db
			return str(a["id"]) < str(b["id"])
	)
	var keep: Array[String] = []
	var limit := maxi(cap, 0)
	for id in pinned:
		if keep.size() >= limit:
			return keep
		keep.append(id)
	for row in rest:
		if keep.size() >= limit:
			break
		keep.append(str(row["id"]))
	return keep


static func footprint_centre(structure: Structure, anchor: Vector2i) -> Vector2:
	var foot := StructurePlacer.footprint(structure, anchor)
	if foot.is_empty():
		return Vector2(anchor)
	var sum := Vector2.ZERO
	for cell in foot:
		sum += Vector2(cell)
	return sum / float(foot.size())


func _refresh() -> void:
	if not _draws or not is_inside_tree():
		return
	if not DayNight.enabled or night_factor(DayNight.elapsed) <= 0.0:
		_drop_all()
		return
	var world := _world()
	var map: TileMap = null
	if world != null:
		map = world.get_node_or_null("worldMap") as TileMap
	if map == null:
		_drop_all()
		return
	var sources := _collect(world, map)
	var chosen := {}
	for id in pick_ids(sources, _camera_pos(world), CAP):
		chosen[id] = true
	var seen := {}
	for src in sources:
		var id := str(src["id"])
		if not chosen.has(id):
			continue
		var light := _ensure(id, str(src["kind"]), src["parent"])
		if light == null:
			continue
		seen[id] = true
		var energy := energy_at(str(src["kind"]), DayNight.elapsed, true)
		if not is_equal_approx(light.energy, energy):
			light.energy = energy
		_place(light, src)
	var stale: Array[String] = []
	for id in _pool:
		if not seen.has(str(id)):
			stale.append(str(id))
	for id in stale:
		_release(id)


func _collect(world: Node2D, map: TileMap) -> Array:
	var sources: Array = []
	for child in world.get_children():
		if not child is CharacterBody2D:
			continue
		(
			sources
			. append(
				{
					"id": "player:%s" % child.name,
					"kind": "player",
					"pos": child.global_position,
					"parent": child,
					"pinned": child.is_multiplayer_authority(),
				}
			)
		)
	var placed: Dictionary = map.placed_structures()
	for sid in placed:
		var meta: Dictionary = placed[sid]
		var structure_name := str(meta.get("name", ""))
		var kind := kind_of(structure_name)
		if kind == "":
			continue
		var anchor: Vector2i = meta["anchor"]
		var turns := int(meta.get("rotation", 0))
		(
			sources
			. append(
				{
					"id": "building:%s" % str(sid),
					"kind": kind,
					"pos": _building_pos(map, structure_name, anchor, turns),
					"parent": world,
					"pinned": false,
				}
			)
		)
	return sources


func _building_pos(map: TileMap, structure_name: String, anchor: Vector2i, turns: int) -> Vector2:
	var structure := _definition(structure_name)
	if structure == null:
		return map.to_global(map.map_to_local(anchor))
	var centre := footprint_centre(Structure.rotated(structure, turns), anchor)
	var tile := Vector2(16, 16)
	if map.tile_set != null:
		tile = Vector2(map.tile_set.tile_size)
	var local := map.map_to_local(anchor) + (centre - Vector2(anchor)) * tile
	return map.to_global(local)


func _definition(structure_name: String) -> Structure:
	if not _defs.has(structure_name):
		_defs[structure_name] = StructurePlacer.load_named(structure_name)
	return _defs[structure_name]


func _camera_pos(world: Node2D) -> Vector2:
	var cam := world.get_viewport().get_camera_2d()
	if cam != null:
		return cam.global_position
	for child in world.get_children():
		if child is CharacterBody2D and child.is_multiplayer_authority():
			return child.global_position
	return world.global_position


func _ensure(id: String, kind: String, parent: Node) -> PointLight2D:
	if parent == null or not is_instance_valid(parent) or not SCALE.has(kind):
		return null
	var have: PointLight2D = _pool.get(id)
	if have != null and is_instance_valid(have) and have.get_parent() == parent:
		return have
	if have != null and is_instance_valid(have):
		have.queue_free()
	var mask := _mask()
	if mask == null:
		return null
	var light := PointLight2D.new()
	light.name = "NightLight_%s" % id.replace(":", "_")
	light.texture = mask
	light.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	light.color = light_color()
	light.texture_scale = float(SCALE[kind])
	light.energy = 0.0
	light.shadow_enabled = false
	light.blend_mode = PointLight2D.BLEND_MODE_ADD
	parent.add_child(light)
	_pool[id] = light
	return light


func _place(light: PointLight2D, src: Dictionary) -> void:
	if str(src["kind"]) == "player":
		if light.position != BODY_OFFSET:
			light.position = BODY_OFFSET
		return
	var at: Vector2 = src["pos"]
	if light.global_position.distance_squared_to(at) > 0.01:
		light.global_position = at


func _mask() -> Texture2D:
	if _texture == null:
		var loaded = load(TEXTURE_PATH)
		if loaded is Texture2D:
			_texture = loaded
	return _texture


func _drop_all() -> void:
	if _pool.is_empty():
		return
	for id in _pool.keys():
		_release(str(id))


func _release(id: String) -> void:
	var node: Node = _pool.get(id)
	_pool.erase(id)
	if node != null and is_instance_valid(node):
		node.queue_free()


func _world() -> Node2D:
	var game := get_node_or_null("/root/Flagoria")
	if game == null:
		return null
	return game.get_node_or_null("World") as Node2D
