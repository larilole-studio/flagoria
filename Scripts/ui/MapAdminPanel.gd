extends PanelContainer
## In-game admin panel for map generation parameters. Touch-friendly at 480x270.

signal closed
signal start_host_requested

## Abbreviations in property names, spelled out in row labels.
const LABEL_WORDS := {"alt": "altitude"}
const DEFAULT_OPEN_GROUP := "Seeds"

var _draft: MapGenParams
var _island_size: OptionButton
var _biome_size: OptionButton
var _spawn_biome: OptionButton
var _raw_values: Dictionary = {}
var _spin_boxes: Dictionary = {}
var _checks: Dictionary = {}

@onready var scroll: ScrollContainer = $Margin/VBox/Scroll
@onready var form: VBoxContainer = $Margin/VBox/Scroll/Form
@onready var seed_alt: LineEdit = $Margin/VBox/Scroll/Form/SeedRow/AltitudeSeed
@onready var seed_moist: LineEdit = $Margin/VBox/Scroll/Form/SeedRow2/MoistureSeed
@onready var seed_temp: LineEdit = $Margin/VBox/Scroll/Form/SeedRow3/TemperatureSeed
@onready var seed_items: LineEdit = $Margin/VBox/Scroll/Form/SeedRow4/ItemsSeed
@onready var seed_biome: LineEdit = $Margin/VBox/Scroll/Form/SeedRow5/BiomeSeed
@onready var noise_type_opt: OptionButton = $Margin/VBox/Scroll/Form/NoiseTypeRow/NoiseType
@onready var simple: VBoxContainer = $Margin/VBox/Simple
@onready var advanced: CheckButton = $Margin/VBox/Advanced


func _ready() -> void:
	var params: MapGenParams = get_node("/root/MapGen").params
	_island_size = _add_choice("IslandSize", "Island size", MapGenParams.SIZE_LABELS)
	_biome_size = _add_choice("BiomeSize", "Biome size", MapGenParams.SIZE_LABELS)
	_spawn_biome = _add_choice(
		"SpawnBiome",
		"Spawn biome",
		["Any", "Oceanic", "Temperate", "Continental", "Dense archipelago"]
	)
	_island_size.item_selected.connect(_select_island_size)
	_biome_size.item_selected.connect(_select_biome_size)
	_spawn_biome.item_selected.connect(func(choice: int): _draft.spawn_biome = choice - 1)
	advanced.toggled.connect(_toggle_advanced)
	_build_groups(params)
	_populate_noise_types()
	load_from_params(params)
	# Every number field is typed on an in-game pad instead of the OS keyboard.
	var pad: NumberPad = preload("res://Scripts/ui/number_pad.tscn").instantiate()
	add_child(pad)
	for field in [seed_alt, seed_moist, seed_temp, seed_items, seed_biome]:
		pad.attach(field)
	for spin in _spin_boxes.values():
		pad.attach_spin_box(spin)
	visibility_changed.connect(
		func():
			pad.close()
			if not visible:
				advanced.set_pressed_no_signal(false)
				scroll.hide()
				simple.show()
				scroll.scroll_vertical = 0
				for group in form.get_children():
					group.get_node("Header").button_pressed = group.name == DEFAULT_OPEN_GROUP
	)


func _add_choice(control_name: String, caption: String, labels: Array) -> OptionButton:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size.x = 140
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var option := OptionButton.new()
	option.name = control_name
	option.custom_minimum_size = Vector2(160, 26)
	for text in labels:
		option.add_item(text)
	row.add_child(label)
	row.add_child(option)
	simple.add_child(row)
	return option


func _select_island_size(choice: int) -> void:
	_draft.set_island_size(choice)
	_show_simple_values()


func _select_biome_size(choice: int) -> void:
	_draft.set_biome_size(choice)
	_show_simple_values()


func _toggle_advanced(enabled: bool) -> void:
	if enabled:
		_show_raw_values()
	else:
		_read_raw_values()
		_show_simple_values()
		get_node("NumberPad").close()
	simple.visible = not enabled
	scroll.visible = enabled


func _show_simple_values() -> void:
	_show_size_choice(_island_size, _draft.island_size_choice())
	_show_size_choice(_biome_size, _draft.biome_size_choice())
	_spawn_biome.select(clampi(_draft.spawn_biome + 1, 0, _spawn_biome.item_count - 1))


func _show_size_choice(option: OptionButton, choice: int) -> void:
	var preset_count := MapGenParams.SIZE_LABELS.size()
	if choice < 0:
		if option.item_count == preset_count:
			option.add_item("Custom")
			option.set_item_disabled(preset_count, true)
		option.select(preset_count)
	else:
		if option.item_count > preset_count:
			option.remove_item(preset_count)
		option.select(choice)


func _populate_noise_types() -> void:
	noise_type_opt.clear()
	noise_type_opt.add_item("Value", FastNoiseLite.TYPE_VALUE)
	noise_type_opt.add_item("Value Cubic", FastNoiseLite.TYPE_VALUE_CUBIC)
	noise_type_opt.add_item("Perlin", FastNoiseLite.TYPE_PERLIN)
	noise_type_opt.add_item("Cellular", FastNoiseLite.TYPE_CELLULAR)
	noise_type_opt.add_item("Simplex", FastNoiseLite.TYPE_SIMPLEX)
	noise_type_opt.add_item("Simplex Smooth", FastNoiseLite.TYPE_SIMPLEX_SMOOTH)


func _build_groups(params: MapGenParams) -> void:
	var bodies: Dictionary[String, Container] = {}
	var custom_controls := {
		"altitude_seed": seed_alt,
		"moisture_seed": seed_moist,
		"temperature_seed": seed_temp,
		"items_seed": seed_items,
		"biome_seed": seed_biome,
		"noise_type": noise_type_opt,
	}
	for prop in params.exported_properties():
		var key: String = prop["name"]
		var group_name: String = prop["group"]
		if group_name.is_empty():
			continue
		if not bodies.has(group_name):
			bodies[group_name] = _add_group(group_name)
		var body := bodies[group_name]
		if custom_controls.has(key):
			var control: Control = custom_controls[key]
			var row := control.get_parent() as HBoxContainer
			row.reparent(body, false)
			continue
		var label := "Day and night" if key == "day_night_cycle" else _label_for(key)
		if prop["type"] == TYPE_BOOL:
			_add_check(body, key, label)
		elif prop["type"] in [TYPE_INT, TYPE_FLOAT]:
			_add_spin(body, key, label, prop)
	if bodies.has(DEFAULT_OPEN_GROUP):
		for row: HBoxContainer in bodies[DEFAULT_OPEN_GROUP].get_children():
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.get_child(0).custom_minimum_size.x = 86
			row.get_child(1).custom_minimum_size = Vector2(104, 20)
	if bodies.has("Game"):
		_build_generate_button(bodies["Game"])


func _add_group(group_name: String) -> Container:
	var group := VBoxContainer.new()
	group.name = group_name
	group.add_theme_constant_override("separation", 3)
	form.add_child(group)
	var header := Button.new()
	header.name = "Header"
	header.custom_minimum_size.y = 24
	header.add_theme_font_size_override("font_size", 12)
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.toggle_mode = true
	group.add_child(header)
	var body: Container
	if group_name == DEFAULT_OPEN_GROUP:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("v_separation", 2)
		body = grid
	else:
		body = VBoxContainer.new()
		body.add_theme_constant_override("separation", 3)
	body.name = "Rows"
	group.add_child(body)
	var expanded := group_name == DEFAULT_OPEN_GROUP
	header.set_pressed_no_signal(expanded)
	_show_group(expanded, group_name, header, body)
	header.toggled.connect(_show_group.bind(group_name, header, body))
	return body


func _show_group(expanded: bool, group_name: String, header: Button, body: Container) -> void:
	header.text = "%s  %s" % ["▾" if expanded else "▸", group_name]
	body.visible = expanded
	var pad := get_node_or_null("NumberPad") as NumberPad
	if not expanded and pad != null and pad.target != null and body.is_ancestor_of(pad.target):
		pad.close()


func _label_for(key: String) -> String:
	## "water_max_alt" -> "Water max altitude", "ground_chance_a" -> "Ground chance A".
	var words := PackedStringArray()
	for word in key.split("_"):
		word = LABEL_WORDS.get(word, word)
		words.append(word.to_upper() if word.length() == 1 else word)
	var text := " ".join(words)
	return text[0].to_upper() + text.substr(1)


func _add_spin(body: Container, key: String, label_text: String, prop: Dictionary) -> void:
	var spin := SpinBox.new()
	spin.rounded = prop["type"] == TYPE_INT
	spin.step = 1.0 if spin.rounded else 0.001
	if prop["hint"] == PROPERTY_HINT_RANGE:
		var bounds: PackedStringArray = prop["hint_string"].split(",")
		spin.min_value = bounds[0].to_float()
		spin.max_value = bounds[1].to_float()
		if not spin.rounded:
			spin.step = bounds[2].to_float() if bounds.size() > 2 else 0.0
	else:
		# Keep plain numeric exports editable within the range a SpinBox can
		# represent exactly for integers.
		spin.min_value = -9007199254740991.0
		spin.max_value = 9007199254740991.0
	spin.custom_minimum_size = Vector2(140, 22)
	spin.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add_row(body, key, label_text, spin)
	_spin_boxes[key] = spin


func _add_check(body: Container, key: String, label_text: String) -> void:
	var check := CheckButton.new()
	check.name = "Check"
	check.custom_minimum_size = Vector2(140, 22)
	_add_row(body, key, label_text, check)
	_checks[key] = check


func _add_row(body: Container, key: String, label_text: String, field: Control) -> void:
	var row := HBoxContainer.new()
	row.name = key
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(140, 0)
	row.add_child(label)
	row.add_child(field)
	body.add_child(row)


func load_from_params(p: MapGenParams) -> void:
	if seed_alt == null:
		return
	_draft = p.duplicate(true) as MapGenParams
	_show_simple_values()
	_show_raw_values()


func _show_raw_values() -> void:
	var p := _draft
	seed_alt.text = str(p.altitude_seed)
	seed_moist.text = str(p.moisture_seed)
	seed_temp.text = str(p.temperature_seed)
	seed_items.text = str(p.items_seed)
	seed_biome.text = str(p.biome_seed)
	var idx = noise_type_opt.get_item_index(p.noise_type)
	if idx >= 0:
		noise_type_opt.select(idx)
	for key in _spin_boxes.keys():
		var spin: SpinBox = _spin_boxes[key]
		spin.set_value_no_signal(p.get(key))
		_raw_values[key] = spin.value
		# SpinBox leaves LineEdit text unchanged when the numeric value is
		# already equal, so a typed-but-uncommitted string can survive a reopen.
		# Int rows show "24", not "24.0", so the pad's digits append cleanly.
		spin.get_line_edit().text = str(int(spin.value)) if spin.rounded else str(spin.value)
	for key in _checks.keys():
		(_checks[key] as CheckButton).button_pressed = bool(p.get(key))


func apply_to_params(p: MapGenParams) -> void:
	if advanced.button_pressed:
		_read_raw_values()
	var inputs := _draft.to_dict()
	var previous := p.to_dict()
	inputs.erase("starter_grove")
	previous.erase("starter_grove")
	if inputs != previous:
		_draft.starter_grove.clear()
	p.from_dict(_draft.to_dict())


func _read_raw_values() -> void:
	_draft.altitude_seed = int(seed_alt.text) if seed_alt.text.is_valid_int() else 0
	_draft.moisture_seed = int(seed_moist.text) if seed_moist.text.is_valid_int() else 0
	_draft.temperature_seed = int(seed_temp.text) if seed_temp.text.is_valid_int() else 0
	_draft.items_seed = int(seed_items.text) if seed_items.text.is_valid_int() else 0
	_draft.biome_seed = int(seed_biome.text) if seed_biome.text.is_valid_int() else 0
	_draft.noise_type = noise_type_opt.get_selected_id()
	for key in _spin_boxes.keys():
		var value: float = _spin_boxes[key].value
		if value != _raw_values[key]:
			_draft.set(key, value)
	for key in _checks.keys():
		_draft.set(key, (_checks[key] as CheckButton).button_pressed)


func _on_random_seed_pressed() -> void:
	apply_to_params(get_node("/root/MapGen").params)
	get_node("/root/MapGen").randomize_seeds()
	load_from_params(get_node("/root/MapGen").params)


func _on_random_specs_pressed() -> void:
	## Roll only the visible choices unless the raw controls are open.
	apply_to_params(get_node("/root/MapGen").params)
	var params: MapGenParams = get_node("/root/MapGen").params
	if advanced.button_pressed:
		params.randomize_specs()
	else:
		params.randomize_seeds()
		params.set_island_size(randi() % MapGenParams.SIZE_LABELS.size())
		params.set_biome_size(randi() % MapGenParams.SIZE_LABELS.size())
		params.spawn_biome = randi_range(
			MapGenParams.ANY_SPAWN_BIOME, BiomeCatalog.ARCHIPELAGO_DENSE
		)
	load_from_params(get_node("/root/MapGen").params)


func _on_reset_pressed() -> void:
	get_node("/root/MapGen").reset_to_defaults()
	load_from_params(get_node("/root/MapGen").params)


func _on_back_pressed() -> void:
	apply_to_params(get_node("/root/MapGen").params)
	get_node("/root/MapGen").save_to_disk()
	hide()
	emit_signal("closed")


func _build_generate_button(body: Container) -> void:
	## Inside the scrolling form, so the pinned Host row stays on screen.
	var button := Button.new()
	button.name = "GenerateBuilding"
	button.text = "Generate building"
	button.custom_minimum_size = Vector2(160, 24)
	button.pressed.connect(_on_generate_building_pressed)
	body.add_child(button)


func _on_generate_building_pressed() -> void:
	## Host only. The placement itself refuses a client. Size and style are
	## whatever the spins say now, including a value not yet saved with Back.
	apply_to_params(get_node("/root/MapGen").params)
	var buildings := get_node_or_null("/root/Flagoria/World/GeneratedBuildings")
	if buildings != null:
		buildings.generate_at_player()


func _on_start_pressed() -> void:
	apply_to_params(get_node("/root/MapGen").params)
	get_node("/root/MapGen").save_to_disk()
	hide()
	emit_signal("start_host_requested")
