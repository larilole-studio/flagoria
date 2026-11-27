extends TileMap

const WORLD_MAP_PARAMS = preload("res://Scripts/world/world_map_params.gd")
const WORLD_CHUNKS = preload("res://Scripts/world/world_chunks.gd")
const WORLD_CELL_QUERIES = preload("res://Scripts/world/world_cell_queries.gd")

## Emitted as the cells change, so local visuals update in that frame.
signal ground_changed(cells: Rect2i)
signal plants_regrown(cells: Array[Vector2i])  # one regrow tick (#353)
signal trees_sprouted(cells: Array[Vector2i])  # one sprout pass (#361)

var count = 0
var moisture = FastNoiseLite.new()
var temperature = FastNoiseLite.new()
var altitude = FastNoiseLite.new()
var items_chance = FastNoiseLite.new()
var biome = FastNoiseLite.new()
var chunk_width: int = 32
var chunk_height: int = 32
var chunk_refresh_frames: int = 15
var player_spawned = false
var spawn_point = Vector2i(0, 0)

# Cached thresholds from MapGenParams (defaults match prior hardcoded values)
var water_max_alt: float = 0.2
var sand_max_alt: float = 0.25
var swamp_special_alt: float = 0.26
var island_radius: int = 0
var island_falloff: float = 1.0
var use_archipelago_preset := false
var archipelago_spacing: int = 0
var archipelago_island_radius: int = 24
var archipelago_jitter: float = 0.5
var archipelago_seed: int = 0
var archipelago_world_extent: int = 0
var archipelago_island_count: int = 0
# Biomes on: cay trees (MapGenParams.cay_trees). Declared above the private
# vars for gdlint; apply_map_params copies it with the other PlantPicker.PARAMS.
var cay_trees: bool = false
var mine_production := MineProduction.new(self)
# predict_cell results by cell; cleared when the params change.
var _predict_cache: Dictionary = {}
var _tree_cuts := TreeCuts.new(self)
var _object_removals := ObjectRemovals.new(self)
## Placed plank bridges (Scripts/mechanics/bridges/bridge_builder.gd).
var _bridges := BridgeBuilder.new(self)
## Placed structures (#270); generate_chunk draws their cells.
var _structures := StructurePlacer.new(self)
## Free-form palisade walls (#276); generate_chunk redraws their pieces.
var _walls := WallBuilder.new(self)
var _castle_front: Variant = null  # outside the starting castle's gate (#271): the spawn once set
## Seconds of play after a cut before any stump regrows, overriding each type's
## regrow_delay; negative (the default) uses the type's. Kept in TreeCuts.
var regrow_delay: float:
	get:
		return _tree_cuts.regrow_delay
	set(value):
		_tree_cuts.regrow_delay = value
## Seconds this map has been played; advanced in _process, cut times use it.
var play_time: float = 0.0
## Altitude shaping (Scripts/world/terrain_shape.gd); reads this map's values.
var _terrain := TerrainShape.new(self)
var _sky := SkyIslands.new()
var ground_chance_a: float = -0.25
var ground_chance_b: float = 0.25
var ground_chance_c: float = 0.75
var bush_min_alt: float = 0.3
var bush_max_alt: float = 0.4
var bush_min_chance: float = 0.0
var tree_min_alt: float = 0.4
var tree_min_chance: float = 0.3
var flower_min_alt: float = 0.25
var flower_max_alt: float = 0.3
var flower_min_chance: float = 0.3
var pine_min_alt: float = 0.5
var pine_min_moist: float = -0.25
var pine_min_chance: float = 0.3
var bushy_tree_min_moist: float = 0.3
var swamp_bush_min_chance: float = 0.3
var birch_min_chance: float = 0.55
var swamp_trees: bool = false
var spawn_biome := MapGenParams.ANY_SPAWN_BIOME
var starter_grove: Dictionary = {}
var biome_frequency: float = 0.0
var biome_seed: int = 0
var biome_edge: float = 0.2
## Per-biome altitude bias and archipelago island density, indexed by biome
## id (MapGenParams, Map Settings); apply_map_params copies them.
var biome_altitude_bias: PackedFloat32Array = MapGenParams.new().biome_altitude_biases()
var biome_island_density: PackedFloat32Array = MapGenParams.new().biome_island_densities()

# Walkable ground decorations (flowers, stones) sit on their own layer at the ground's
# z_index so the player always draws over them; layer 1 (bushes, trees) is z 1.
const GROUND_DECOR_LAYER := 2
# plant_tile result for a cell without a plant.
const NO_PLANT := Vector2i(-1, -1)

# Spawn search constants other scripts and tests read from the map.
const SPAWN_MIN_REACHABLE := SpawnFinder.SPAWN_MIN_REACHABLE
const SPAWN_RADIUS := SpawnFinder.SPAWN_RADIUS
const SPAWN_CLEARANCE := SpawnFinder.SPAWN_CLEARANCE


func _ready():
	apply_map_params(get_node("/root/MapGen").params)


func apply_map_params(p: MapGenParams) -> void:
	WORLD_MAP_PARAMS.apply_map_params(self, p)


func invalidate_painted_cell(cell: Vector2i) -> void:
	WORLD_CHUNKS.invalidate_painted_cell(self, cell)


func _process(delta):
	WORLD_CHUNKS.refresh(self, delta)


func generate_chunk(position) -> void:
	WORLD_CHUNKS.generate_chunk(self, position)


func cell_altitude(cell: Vector2i, biome_id: int) -> float:
	return _terrain.cell_altitude(cell, biome_id)


func island_altitude(cell: Vector2i, alt: float) -> float:
	return _terrain.island_altitude(cell, alt)


func archipelago_altitude(cell: Vector2i, alt: float) -> float:
	return _terrain.archipelago_altitude(cell, alt)


func archipelago_centre(square: Vector2i) -> Vector2:
	return _terrain.archipelago_centre(square)


func archipelago_square_active(square: Vector2i) -> bool:
	return _terrain.archipelago_square_active(square)


func biome_at(cell: Vector2i) -> int:
	return WORLD_CHUNKS.biome_at(self, cell)


func ground_tile(
	alt: float, moist: float, chance: float, biome_id: int = BiomeCatalog.TEMPERATE
) -> Vector2i:
	return _sky.ground_tile(self, alt, moist, chance, biome_id)


func get_random_ground_vec(chance):
	return WORLD_CHUNKS.get_random_ground_vec(self, chance)


func set_tile_type_z1(pos_vec, alt, moist, _temp, chance, biome_id: int = BiomeCatalog.TEMPERATE):
	WORLD_CHUNKS.set_tile_type_z1(self, pos_vec, alt, moist, _temp, chance, biome_id)


func plant_tile(
	alt: float, moist: float, chance: float, biome_id: int = BiomeCatalog.TEMPERATE
) -> Vector2i:
	## Bush, tree, bushy tree, pine, flower or NO_PLANT for one walkable cell (PlantPicker).
	return PlantPicker.plant_tile(self, alt, moist, chance, biome_id)


func structure_tile(chance: float, biome_id: int = BiomeCatalog.TEMPERATE) -> Vector2i:
	## Stones or NO_PLANT for one walkable cell with no plant (PlantPicker).
	return PlantPicker.structure_tile(self, chance, biome_id)


func predict_cell(cell: Vector2i) -> Array:
	return WORLD_CHUNKS.predict_cell(self, cell)


func predicted_clear(cell: Vector2i) -> bool:
	return WORLD_CHUNKS.predicted_clear(self, cell)


func choppable(cell: Vector2i) -> InteractableType:
	return _tree_cuts.choppable(cell)


func has_tree(cell: Vector2i, include_unpainted := false) -> bool:
	return _tree_cuts.has_tree(cell, include_unpainted)


func cut_choppable(cell: Vector2i) -> InteractableType:
	return _tree_cuts.cut_choppable(cell)


func regrow_due() -> int:
	var cells := _tree_cuts.regrow_due()
	if not cells.is_empty():
		plants_regrown.emit(cells)
	return cells.size()


func grow_back(cell: Vector2i) -> bool:
	return _tree_cuts.grow_back(cell)


func cut_changes() -> Dictionary[String, Dictionary]:
	return _tree_cuts.to_changes()


func object_changes() -> Dictionary[String, Dictionary]:
	return _object_removals.object_changes_with(_tree_cuts)


func restore_cuts(changes: Dictionary) -> int:
	return _tree_cuts.restore(changes)


func restore_object_changes(changes: Dictionary) -> int:
	return _object_removals.restore_with(_tree_cuts, changes)


func replace_cuts(changes: Dictionary) -> int:
	return _tree_cuts.replace(changes)


func replace_object_changes(changes: Dictionary) -> int:
	return _object_removals.replace_with(_tree_cuts, changes)


func pick_decor(cell: Vector2i) -> bool:
	return _object_removals.pick(cell)


func mineable_rock(cell: Vector2i) -> bool:
	return _object_removals.mineable_rock(cell)


func mine_impact(cell: Vector2i, interaction: Interaction) -> void:
	if multiplayer.is_server():
		_object_removals.resolve_mine_hit(interaction, cell, interaction.player, 1)
	elif (
		multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
	):
		request_mine_hit.rpc_id(1, cell)


@rpc("any_peer", "reliable", "call_remote")
func request_mine_hit(cell: Vector2i) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	var interaction := get_node("../Interaction") as Interaction
	if interaction.cut_limit.allow(peer):
		var miner := get_node_or_null("../" + str(peer)) as Node2D
		_object_removals.resolve_mine_hit(interaction, cell, miner, peer)


@rpc("authority", "reliable", "call_remote")
func apply_mine_hit(cell: Vector2i, depleted: bool) -> void:
	_object_removals.apply_mine_hit(cell, depleted)


func destroy_decor(cell: Vector2i) -> bool:
	return _object_removals.destroy(cell)


func has_live_rock(cell: Vector2i) -> bool:
	return _object_removals.decor_at(cell) == TileCatalog.STONES


func cut_grown(cell: Vector2i) -> InteractableType:
	return _tree_cuts.cut_grown(cell)


func build_bridge(from: Vector2i, to: Vector2i) -> bool:
	return _bridges.build_bridge(from, to)


func erase_bridge_cells(cells: Array[Vector2i]) -> bool:
	return _bridges.erase_cells(cells)


func has_bridge(cell: Vector2i) -> bool:
	return _bridges.has_bridge(cell)


func set_bridge_cell(cell: Vector2i, atlas: Vector2i) -> void:
	## Bridge piece with no adjacency checks (tests: occupied mid-run cell).
	_bridges.set_cell(cell, atlas)


func forget_cut(cell: Vector2i) -> void:
	## Drop stump/sprout on `cell` without regrowing (structure or wall covers it).
	_tree_cuts.forget(cell)


func has_cut(cell: Vector2i) -> bool:
	return _tree_cuts.has_cut(cell)


func cut_type(cell: Vector2i) -> InteractableType:
	return _tree_cuts.cut_type(cell)


func tree_sprouts() -> TreeSprouts:
	return _tree_cuts.sprouts


func place_wall_cells(cells: Array[Vector2i]) -> bool:
	return _walls.place_cells(cells)


func has_wall(cell: Vector2i) -> bool:
	return _walls.has_wall(cell)


func free_wall_cells() -> Array:
	return _walls.free_cells()


func wall_hp(cell: Vector2i) -> int:
	return _walls.hp(cell)


func damage_wall_cell(cell: Vector2i) -> int:
	return _walls.damage(cell)


func erase_wall_cells(cells: Array[Vector2i]) -> bool:
	return _walls.erase_cells(cells)


func replace_wall_cells_from_host(cells: Array) -> void:
	_walls.replace_from_host(cells)


func set_wall_hp(cell: Vector2i, amount: int) -> void:
	_walls.set_hp(cell, amount)


func auto_structure_cells() -> Array:
	return _structures.auto_cells().keys()


func structure_object_at(cell: Vector2i) -> Vector2i:
	return _structures.object_at(cell)


func apply_solved_auto_junction(cell: Vector2i, tile_name: String) -> void:
	_structures.apply_solved(cell, tile_name)


func can_place_structure(
	structure: Structure, anchor_cell: Vector2i, quarter_turns: int = 0
) -> Array[String]:
	return _structures.can_place(structure, anchor_cell, quarter_turns)


func place_structure(
	structure: Structure, anchor_cell: Vector2i, owner: int, quarter_turns: int = 0
) -> int:
	return _structures.place(structure, anchor_cell, owner, quarter_turns)


func placed_structures() -> Dictionary:
	return _structures.placements()


func structure_placement_at(cell: Vector2i) -> Dictionary:
	return _structures.placement_details_at(cell)


func remove_structure(id: int) -> bool:
	return _structures.remove(id)


func place_start_castle(owner: int) -> bool:
	## Peer `owner`'s starting castle by the spawn (StartCastle); false when none fits.
	_castle_front = StartCastle.place(self, owner)
	if _castle_front != null:
		spawn_point = _castle_front
	return _castle_front != null


func structures_for_sync(include_identity := false) -> Array:
	return _structures.to_sync(include_identity)


func replace_structures(list: Array) -> int:
	return _structures.replace_from_host(list)


func bridges_for_sync() -> Array:
	return _bridges.to_sync()


func replace_bridges(list: Array) -> int:
	return _bridges.replace_from_host(list)


static func bridge_pieces(
	length: int, horizontal: bool, land_before: bool, land_after: bool
) -> Array[Vector2i]:
	return BridgeBuilder.bridge_pieces(length, horizontal, land_before, land_after)


func player_on_cell(cell: Vector2i) -> bool:
	return WORLD_CELL_QUERIES.player_on_cell(self, cell)


func mob_cells() -> Dictionary:
	return WORLD_CELL_QUERIES.mob_cells(self)


func mob_on_cell(cell: Vector2i) -> bool:
	return mob_cells().has(cell)


func ground_is_walkable(atlas: Vector2i) -> bool:
	return WORLD_CELL_QUERIES.ground_is_walkable(self, atlas)


func is_drawn(cell: Vector2i) -> bool:
	return _sky.is_drawn(self, cell)


func is_open_sea(cell: Vector2i) -> bool:
	return _sky.is_open_sea(self, cell)


func repaint_ground_cell(cell: Vector2i) -> void:
	WORLD_CHUNKS.repaint_ground_cell(self, cell)


func sea_cells() -> Array:
	return _sky.sea_cells()


func claim_ground(cell: Vector2i, atlas: Vector2i) -> void:
	_sky.claim(self, cell, atlas)


func is_walkable_land(cell: Vector2i) -> bool:
	return WORLD_CELL_QUERIES.is_walkable_land(self, cell)


func count_walkable_neighbors(cell: Vector2i) -> int:
	return SpawnFinder.count_walkable_neighbors(self, cell)


func is_clear_ground(cell: Vector2i) -> bool:
	return WORLD_CELL_QUERIES.is_clear_ground(self, cell)


func reachable_clear_cells(
	start: Vector2i, limit: int = SpawnFinder.SPAWN_MIN_REACHABLE
) -> Array[Vector2i]:
	return SpawnFinder.reachable_clear_cells(self, start, limit)


func resolve_player_spawn(
	origin_cell: Vector2i = Vector2i(0, 0), max_radius: int = 192
) -> Vector2i:
	return WORLD_CELL_QUERIES.resolve_player_spawn(self, origin_cell, max_radius)


func ensure_starter_wood(origin_cell: Vector2i) -> Array[int]:
	var cells := SpawnFinder.starter_wood_cells(self, origin_cell)
	var coordinates: Array[int] = []
	for cell in cells:
		starter_grove[cell] = true
		erase_cell(GROUND_DECOR_LAYER, cell)
		invalidate_painted_cell(cell)
		coordinates.append_array([cell.x, cell.y])
	if not cells.is_empty():
		generate_chunk(map_to_local(origin_cell))
	return coordinates


func spawn_spots(
	origin_cell: Vector2i, limit: int = SpawnFinder.SPAWN_SEARCH_LIMIT
) -> Array[Vector2]:
	return SpawnFinder.spawn_spots(self, origin_cell, limit)


func free_spawn_position(origin_cell: Vector2i, taken: Array[Vector2]) -> Vector2:
	return SpawnFinder.free_spawn_position(self, origin_cell, taken)
