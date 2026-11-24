extends RefCounted
## Applies generation settings and resets the generated map.


static func apply_map_params(map, p: MapGenParams) -> void:
	## Apply the full parameter set and clear existing tiles so the next chunk regen is clean.
	var working = p.duplicate_params()
	working.ensure_seeds()

	_configure_noise(map.altitude, working.altitude_seed, working.altitude_frequency, working)
	_configure_noise(map.moisture, working.moisture_seed, working.moisture_frequency, working)
	_configure_noise(
		map.temperature, working.temperature_seed, working.temperature_frequency, working
	)
	_configure_noise(map.items_chance, working.items_seed, working.items_frequency, working)

	map.spawn_biome = working.spawn_biome
	map.starter_grove.clear()
	for index in range(0, working.starter_grove.size(), 2):
		map.starter_grove[Vector2i(working.starter_grove[index], working.starter_grove[index + 1])] = true
	map.biome_frequency = working.biome_frequency
	map.biome_seed = working.biome_seed
	map.biome_edge = working.biome_edge
	map.biome_altitude_bias = working.biome_altitude_biases()
	map.biome_island_density = working.biome_island_densities()
	if map.biome_frequency > 0.0:
		_configure_noise(map.biome, working.biome_seed, working.biome_frequency, working)

	map.chunk_width = working.chunk_width
	map.chunk_height = working.chunk_height
	map.chunk_refresh_frames = maxi(1, working.chunk_refresh_frames)
	map.water_max_alt = working.water_max_alt
	map.sand_max_alt = working.sand_max_alt
	map.swamp_special_alt = working.swamp_special_alt
	map.island_radius = working.island_radius
	map.use_archipelago_preset = working.island_size_choice() >= 0
	map.island_falloff = working.island_falloff
	map.archipelago_spacing = working.archipelago_spacing
	map.archipelago_island_radius = maxi(1, working.archipelago_island_radius)
	map.archipelago_jitter = working.archipelago_jitter
	map.archipelago_seed = working.altitude_seed
	map.archipelago_world_extent = maxi(0, working.archipelago_world_extent)
	map.archipelago_island_count = maxi(0, working.archipelago_island_count)
	map._terrain._rebuild_archipelago_active_squares()
	map.ground_chance_a = working.ground_chance_a
	map.ground_chance_b = working.ground_chance_b
	map.ground_chance_c = working.ground_chance_c
	for key in PlantPicker.PARAMS:
		map.set(key, working.get(key))

	map.clear()
	map._sky.clear()
	map._predict_cache.clear()
	map._tree_cuts.clear()
	map._object_removals.clear()
	map._bridges.clear()
	map._structures.clear()
	map._walls.clear()
	map._castle_front = null
	map.spawn_point = Vector2i(0, 0)
	if map.has_meta(&"resolved_spawn"):
		map.remove_meta(&"resolved_spawn")
	map.ground_changed.emit(Rect2i())


static func _configure_noise(
	noise: FastNoiseLite, seed_value: int, frequency: float, p: MapGenParams
) -> void:
	noise.seed = seed_value
	noise.noise_type = p.noise_type
	noise.frequency = frequency
	noise.fractal_octaves = p.fractal_octaves
	noise.fractal_lacunarity = p.fractal_lacunarity
	noise.fractal_gain = p.fractal_gain
