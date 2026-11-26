extends "res://tests/helpers/test_helpers.gd"
## The docs/interactables.md checklist as a check (#269): every type in
## data/interactables/ must pass each step a machine can check, or the run
## fails naming the type and the step. The steps a person has to judge (does
## the art read well, does the sound fit, does the test cover the chop) are
## listed in docs/interactables.md.

const DATA_DIR := "res://data/interactables/"
const TILESET := "res://art/flagoria/flagoria_tiles_v3.tres"
const SFX_DIR := "res://art/audio/sfx/world/"
const AUDIO_CREDITS := "res://art/audio/CREDITS.md"
const ART_CREDITS := "res://art/flagoria/CREDITS.md"
const TILES_DOC := "res://docs/tiles.md"
const CHECKLIST_DOC := "res://docs/interactables.md"
const TESTS_DIR := "res://tests/mechanics/"
const FEATURES_DIR := "res://.cursor/skills/verify-flagoria/features/"
const SOUND_SLOTS := [
	"hit_sounds", "hit_layer_sounds", "last_hit_sounds", "fell_sounds", "pickup_sounds"
]


func _test_checklist_types_on_main() -> int:
	## Every .tres in data/interactables/ is in InteractableCatalog.TYPES (and
	## the other way round), and every type passes every mechanical step.
	print("-- test_checklist_types_on_main")
	var fail := 0
	var files := {}
	for f in DirAccess.get_files_at(DATA_DIR):
		if f.ends_with(".tres"):
			files[DATA_DIR + f] = true
	var registered := {}
	for type: InteractableType in InteractableCatalog.TYPES:
		registered[type.resource_path] = true
		if not files.has(type.resource_path):
			printerr(
				(
					"FAIL checklist: %s: step 1 data: %s is in InteractableCatalog.TYPES but not in %s"
					% [type.id, type.resource_path, DATA_DIR]
				)
			)
			fail += 1
	for path: String in files:
		if not registered.has(path):
			printerr(
				(
					"FAIL checklist: %s: step 1 data: not in InteractableCatalog.TYPES (interactable_catalog.gd)"
					% path.get_file().get_basename()
				)
			)
			fail += 1
	for msg in checklist_errors(InteractableCatalog.TYPES):
		printerr("FAIL checklist: " + msg)
		fail += 1
	return fail


func _test_checklist_fixtures_fail() -> int:
	## A copy of a real type with one step broken fails that step, with the
	## type id and step number in the message, and no other step.
	print("-- test_checklist_fixtures_fail")
	var fail := 0
	var bad_wav := AudioStreamWAV.new()  # an unsaved stream, not a file
	var cases := [
		["hits", 0, "tree", "step 1 data"],
		["leaves", "NO_SUCH_TILE", "tree", "step 1 data"],
		["regrow_delay", -5.0, "bush", "step 1 data"],
		["variants", art_fixture("GRASS_A"), "bush", "step 2 art"],
		["variants", art_fixture("NO_SUCH_TILE"), "bush", "step 2 art"],
		["leaves", "TREE", "bush", "step 2 art"],
		["variants", art_fixture("BUSH", "fx_sheet"), "bush", "step 2 art"],
		["variants", art_fixture("BUSH", "hit_sheet"), "bush", "step 2 art"],
		["hit_sounds", _streams([bad_wav]), "tree", "step 3 sound"],
		["fell_sounds", _streams([]), "bush", "step 3 sound"],
		["yields", _yields({}), "tree", "step 4 yield"],
		["yields", _yields({&"wood": 0}), "bush", "step 4 yield"],
		["yields", _yields({&"gold": 2}), "bush", "step 4 yield"],
		["save_key", "", "pine", "step 5 save"],
		["save_key", "tree", "pine", "step 5 save"],
		["id", "fern", "bush", "step 6 tests"],
		["id", "fern", "bush", "step 7 verification"],
		["id", "fern", "bush", "docs"],
	]
	for c in cases:
		var types := InteractableCatalog.TYPES.duplicate()
		var i := types.find(InteractableCatalog.by_id(c[2]))
		var broken: InteractableType = types[i].duplicate()
		broken.set(c[0], c[1])
		if broken.get(c[0]) != c[1]:
			printerr("FAIL checklist_fixtures: could not set %s to %s" % [c[0], c[1]])
			fail += 1
		types[i] = broken
		var msgs := checklist_errors(types)
		var hit := msgs.filter(
			func(m: String) -> bool: return m.begins_with(broken.id + ": " + c[3])
		)
		var other := msgs.filter(
			func(m: String) -> bool: return not m.begins_with(broken.id + ": ")
		)
		if hit.is_empty() or not other.is_empty():
			printerr(
				(
					"FAIL checklist_fixtures: %s = %s on %s gave %s, want a '%s' failure for %s only"
					% [c[0], c[1], c[2], msgs, c[3], broken.id]
				)
			)
			fail += 1
	return fail


func art_fixture(tile: String, bad_sheet := "") -> Array[ChopSprites]:
	var sprites: ChopSprites = InteractableCatalog.by_id("bush").variants[0].duplicate()
	sprites.idle_tiles = [tile]
	if not bad_sheet.is_empty():
		sprites.set(
			bad_sheet,
			ImageTexture.create_from_image(Image.create_empty(9, 9, false, Image.FORMAT_RGBA8))
		)
	return [sprites]


func _streams(a: Array) -> Array[AudioStream]:
	var out: Array[AudioStream] = []
	out.assign(a)
	return out


func _yields(d: Dictionary) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	out.assign(d)
	return out


func checklist_errors(types: Array) -> Array[String]:
	## One message per failed step, "<id>: step N <name>: what is wrong".
	var out: Array[String] = []
	var tile_set: TileSet = load(TILESET)
	var src := tile_set.get_source(TileCatalog.SOURCE_ID) as TileSetAtlasSource
	var tiles_doc := _read(TILES_DOC)
	var art_credits := _read(ART_CREDITS)
	var audio_credits := _read(AUDIO_CREDITS)
	var keys := {}
	var tile_owner := {}
	var resources := Inventory.new()
	var known: Array = resources.get_script().get_script_constant_map().values().filter(
		func(v) -> bool: return v is StringName
	)
	resources.free()
	for type: InteractableType in types:
		var e := func(step: String, what: String) -> void:
			out.append("%s: %s: %s" % [type.id, step, what])
		# 1. Data: fields set and valid.
		if type.id == "" or type.variants.is_empty():
			e.call("step 1 data", "id and variants must be set")
		if type.hits < 1:
			e.call("step 1 data", "hits is %d, want 1 or more" % type.hits)
		if type.regrow_delay < 0.0:
			e.call(
				"step 1 data",
				"regrow_delay is %s; 0 means never, it cannot be negative" % type.regrow_delay
			)
		if not TileCatalog.TILES.has(type.leaves):
			e.call("step 1 data", "leaves %s is not in TileCatalog.TILES" % type.leaves)
		# 2. Art: tiles in the catalog and TileSet, collision, tiles.md, credits.
		for sprites: ChopSprites in type.variants:
			check_sprite_art(sprites, src, tiles_doc, art_credits, tile_owner, type.id, e)
		if TileCatalog.TILES.has(type.leaves):
			var left: Vector2i = TileCatalog.TILES[type.leaves]["atlas"]
			if not src.has_tile(left) or _polygons(src, left, 0) > 0:
				e.call(
					"step 2 art", "leaves %s must be in the TileSet with no collision" % type.leaves
				)
			if not tiles_doc.contains("| (%d, %d) |" % [left.x, left.y]):
				e.call("step 2 art", "leaves %s has no row in docs/tiles.md" % type.leaves)
		# 3. Sound: files in one world/<group>/ folder, 22,050 Hz mono 16-bit, credited.
		if type.hit_sounds.is_empty() or type.fell_sounds.is_empty():
			e.call("step 3 sound", "hit_sounds and fell_sounds must not be empty")
		var groups := {}
		for slot in SOUND_SLOTS:
			for s in type.get(slot):
				var wav := s as AudioStreamWAV
				var path: String = s.resource_path if s != null else ""
				if not path.begins_with(SFX_DIR) or not FileAccess.file_exists(path):
					e.call(
						"step 3 sound",
						(
							"%s has %s, want a .wav file under %s<group>/"
							% [slot, path if path != "" else "an unsaved stream", SFX_DIR]
						)
					)
					continue
				groups[path.get_base_dir()] = true
				if wav == null or _wav_format(path) != [1, 22050, 16]:
					e.call(
						"step 3 sound",
						(
							"%s %s is %s (channels, Hz, bits), want 22,050 Hz mono 16-bit"
							% [slot, path, _wav_format(path)]
						)
					)
				if not _credited(audio_credits, path.trim_prefix("res://art/audio/")):
					e.call(
						"step 3 sound", "%s %s is not credited in %s" % [slot, path, AUDIO_CREDITS]
					)
		if groups.size() > 1:
			e.call(
				"step 3 sound",
				"sounds come from %d folders %s, want one group" % [groups.size(), groups.keys()]
			)
		# 4. Yield: at least one known resource, each above 0.
		if type.yields.is_empty():
			e.call("step 4 yield", "yields is empty")
		for r in type.yields:
			if type.yields[r] <= 0 or not known.has(r):
				e.call(
					"step 4 yield",
					(
						"yields %s: %s, want a resource in Inventory (%s) above 0"
						% [r, type.yields[r], known]
					)
				)
		# 5. Save: save_key set and unique.
		if type.save_key == "":
			e.call("step 5 save", "save_key is empty")
		elif keys.has(type.save_key):
			e.call("step 5 save", "save_key %s is also %s's" % [type.save_key, keys[type.save_key]])
		keys[type.save_key] = type.id
		# 6. Tests: a test file named for the type, or one that names its id.
		if not _has_test(type.id):
			e.call(
				"step 6 tests",
				(
					'no tests/mechanics/**/test_%s*.gd and no test there names "%s"'
					% [type.id, type.id]
				)
			)
		# 7. Verification: a feature file names the data file, and features/README.md lists it.
		var features := _features_naming(type.id + ".tres")
		var index := _read(FEATURES_DIR + "README.md")
		if features.is_empty():
			e.call(
				"step 7 verification", "no %s*.md names %s.tres (#291)" % [FEATURES_DIR, type.id]
			)
		elif features.all(func(f: String) -> bool: return not index.contains("(./%s)" % f)):
			e.call("step 7 verification", "%s: no line in features/README.md" % ", ".join(features))
		# The checklist doc names every type.
		if not _names(_read(CHECKLIST_DOC), type.id):
			e.call("docs", "docs/interactables.md does not name it")
	return out


func check_sprite_art(
	sprites: ChopSprites,
	src: TileSetAtlasSource,
	tiles_doc: String,
	art_credits: String,
	tile_owner: Dictionary,
	id: String,
	error: Callable
) -> void:
	if sprites == null or sprites.idle_tiles.is_empty():
		error.call("step 2 art", "variant needs idle tiles")
		return
	for i in sprites.idle_tiles.size():
		var n := sprites.idle_tiles[i]
		if not TileCatalog.TILES.has(n):
			error.call("step 2 art", "tile %s is not in TileCatalog.TILES" % n)
			continue
		var atlas: Vector2i = TileCatalog.TILES[n]["atlas"]
		if tile_owner.has(n):
			error.call("step 2 art", "tile %s is also %s's" % [n, tile_owner[n]])
		tile_owner[n] = id
		if not src.has_tile(atlas) or (i == 0 and _polygons(src, atlas, 0) == 0):
			error.call("step 2 art", "tile %s is missing or its trunk has no collision" % n)
		elif (
			not src.has_alternative_tile(atlas, ChopAction.HIDDEN_ALT)
			or (_polygons(src, atlas, ChopAction.HIDDEN_ALT) != _polygons(src, atlas, 0))
		):
			error.call(
				"step 2 art", "tile %s needs a hidden alternative with matching collision" % n
			)
		if not tiles_doc.contains("| (%d, %d) |" % [atlas.x, atlas.y]):
			error.call("step 2 art", "tile %s %s has no row in docs/tiles.md" % [n, atlas])
	for sheet_name in ["hit_sheet", "fx_sheet"]:
		var sheet: Texture2D = sprites.get(sheet_name)
		if sheet == null:
			error.call("step 2 art", "%s is missing" % sheet_name)
			continue
		var frame_height := 16 * sprites.idle_tiles.size()
		var size := Vector2i(sheet.get_size())
		if sheet_name == "hit_sheet":
			if (
				size.x != 32
				or size.y % frame_height != 0
				or not (sprites.hit_row >= 0 and (sprites.hit_row + 1) * frame_height <= size.y)
			):
				error.call("step 2 art", "hit sheet has the wrong size or hit row")
		elif size != Vector2i(64, 16):
			error.call("step 2 art", "fx sheet must contain four 16x16 frames")
		if not art_credits.contains(sheet.resource_path.get_file()):
			error.call("step 2 art", "%s %s is not credited" % [sheet_name, sheet.resource_path])


func _polygons(src: TileSetAtlasSource, atlas: Vector2i, alt: int) -> int:
	return src.get_tile_data(atlas, alt).get_collision_polygons_count(0)


func _wav_format(path: String) -> Array:
	## [channels, sample rate, bits] from the .wav header. The imported stream
	## may be compressed, so its own mix_rate and format say nothing.
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() < 36:
		return []
	f.seek(22)
	var channels := f.get_16()
	var rate := f.get_32()
	f.seek(34)
	return [channels, rate, f.get_16()]


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _names(text: String, id: String) -> bool:
	## `id` as a word, or its plural (bush, bushes).
	var re := RegEx.create_from_string("\\b%s(e?s)?\\b" % id)
	return re.search(text) != null


func _credited(credits: String, rel: String) -> bool:
	## `rel` itself in backticks, or inside a "`x_01.wav` … `_NN.wav`" range.
	if credits.contains("`%s`" % rel):
		return true
	var m := RegEx.create_from_string("^(.*)_(\\d\\d)\\.wav$").search(rel)
	if m == null:
		return false
	var top := (
		RegEx
		. create_from_string("`%s_01\\.wav` … `_(\\d\\d)\\.wav`" % m.get_string(1))
		. search(credits)
	)
	return top != null and int(top.get_string(1)) >= int(m.get_string(2))


func _has_test(id: String) -> bool:
	for path in _files(TESTS_DIR, ".gd"):
		var f := path.get_file()
		if f == "test_checklist.gd":  # its fixtures name made-up ids
			continue
		if (
			f.begins_with("test_" + id)
			or (f.begins_with("test_") and _read(path).contains('"%s"' % id))
		):
			return true
	return false


func _features_naming(text: String) -> Array[String]:
	var out: Array[String] = []
	for path in _files(FEATURES_DIR, ".md"):
		if path.get_file() != "README.md" and _read(path).contains(text):
			out.append(path.get_file())
	return out


func _files(dir: String, ext: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(ext):
			out.append(dir + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_files(dir + d + "/", ext))
	return out
