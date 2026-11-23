extends "res://tests/helpers/test_helpers.gd"
## Night pools (#560): energy through the day, and the mobile light cap.

const KINDS: Array[String] = ["player", "castle", "tower", "guard_post"]


func _test_night_lights_energy() -> int:
	## Day is off, dusk rises with the smoothstep, night is the table energy.
	## A headless run creates no PointLight2D and does not process.
	## Time cost: under 0.1 s in tools/verify.sh.
	print("-- test_night_lights_energy")
	var fail := 0
	var spec = JSON.parse_string(FileAccess.get_file_as_string("res://docs/day_night.json"))
	if not spec is Dictionary or not spec.has("lights"):
		printerr("FAIL night_lights_energy: docs/day_night.json did not parse")
		return 1
	var lights: Dictionary = spec["lights"]
	if (
		str(lights.get("color", "")) != NightLights.COLOR_HEX
		or NightLights.light_color().to_html(false) != "f2b632"
	):
		printerr("FAIL night_lights_energy color %s" % lights.get("color"))
		fail += 1
	if int(lights.get("mobile_cap", 0)) != NightLights.CAP:
		printerr("FAIL night_lights_energy cap %s" % lights.get("mobile_cap"))
		fail += 1
	if str(lights.get("texture", "")) != "art/day_night/light_radial_smooth_128.png":
		printerr("FAIL night_lights_energy texture %s" % lights.get("texture"))
		fail += 1
	if not FileAccess.file_exists(NightLights.TEXTURE_PATH):
		printerr("FAIL night_lights_energy: light texture missing")
		fail += 1
	var sources: Dictionary = lights.get("sources", {})
	for kind in KINDS:
		if not sources.has(kind):
			printerr("FAIL night_lights_energy: no %s source" % kind)
			fail += 1
			continue
		var row: Dictionary = sources[kind]
		var full := float(row["energy"])
		var scale := float(row["texture_scale"])
		if (
			not is_equal_approx(full, float(NightLights.ENERGY[kind]))
			or not is_equal_approx(scale, float(NightLights.SCALE[kind]))
			or not is_equal_approx(float(row["radius_px"]), scale * 64.0)
		):
			printerr("FAIL night_lights_energy %s row %s" % [kind, row])
			fail += 1
		var day := NightLights.energy_at(kind, 180.0)
		var early := NightLights.energy_at(kind, 375.0)
		var late := NightLights.energy_at(kind, 405.0)
		var night := NightLights.energy_at(kind, 480.0)
		var want_early := full * DayNight.cycle_ease(15.0 / 60.0)
		var want_late := full * DayNight.cycle_ease(45.0 / 60.0)
		if (
			day != 0.0
			or not is_equal_approx(night, full)
			or not is_equal_approx(early, want_early)
			or not is_equal_approx(late, want_late)
			or not (early > 0.0 and late > early and late < night)
		):
			printerr(
				(
					"FAIL night_lights_energy %s day=%s dusk=%s/%s night=%s"
					% [kind, day, early, late, night]
				)
			)
			fail += 1
		if (
			not is_equal_approx(NightLights.energy_at(kind, 360.0), 0.0)
			or not is_equal_approx(NightLights.energy_at(kind, 420.0), full)
			or not is_equal_approx(NightLights.energy_at(kind, 540.0), full)
			or not is_equal_approx(NightLights.energy_at(kind, 600.0), 0.0)
			or not is_equal_approx(NightLights.energy_at(kind, 480.0, false), 0.0)
		):
			printerr("FAIL night_lights_energy %s bounds" % kind)
			fail += 1
	if (
		NightLights.kind_of("castle") != "castle"
		or NightLights.kind_of("tower_wood") != "tower"
		or NightLights.kind_of("guard_post") != "guard_post"
		or NightLights.kind_of("barracks") != ""
	):
		printerr("FAIL night_lights_energy kinds")
		fail += 1
	var node := DayNight.get_node_or_null("NightLights")
	if (
		node == null
		or node.is_processing()
		or node.is_physics_processing()
		or node.find_children("", "PointLight2D", true, false).size() != 0
	):
		printerr("FAIL night_lights_energy: headless host created a light or is processing")
		fail += 1
	if fail == 0:
		print("PASS test_night_lights_energy")
	return fail


func _test_night_lights_cap() -> int:
	## More lit buildings than the cap: the local player stays, the nearest
	## buildings stay, the farthest are dropped.
	## Time cost: under 0.1 s in tools/verify.sh.
	print("-- test_night_lights_cap")
	var fail := 0
	var sources: Array = [{"id": "player:1", "pos": Vector2.ZERO, "pinned": true}]
	for i in 20:
		(
			sources
			. append(
				{
					"id": "building:%d" % i,
					"pos": Vector2(10.0 * float(i + 1), 0.0),
					"pinned": false,
				}
			)
		)
	var keep := NightLights.pick_ids(sources, Vector2.ZERO, NightLights.CAP)
	if keep.size() != NightLights.CAP or not keep.has("player:1"):
		printerr("FAIL night_lights_cap size %s player %s" % [keep.size(), keep.has("player:1")])
		fail += 1
	for i in 15:
		if not keep.has("building:%d" % i):
			printerr("FAIL night_lights_cap dropped near building %s" % i)
			fail += 1
	for i in range(15, 20):
		if keep.has("building:%d" % i):
			printerr("FAIL night_lights_cap kept far building %s" % i)
			fail += 1
	# The local player stays even when every building is closer to the camera.
	var far: Array = [{"id": "player:1", "pos": Vector2(5000, 0), "pinned": true}]
	for i in NightLights.CAP:
		far.append({"id": "building:%d" % i, "pos": Vector2(float(i), 0.0), "pinned": false})
	var kept_far := NightLights.pick_ids(far, Vector2.ZERO, NightLights.CAP)
	if (
		kept_far.size() != NightLights.CAP
		or not kept_far.has("player:1")
		or kept_far.has("building:%d" % (NightLights.CAP - 1))
	):
		printerr("FAIL night_lights_cap pinned player lost: %s" % " ".join(kept_far))
		fail += 1
	var few: Array = [
		{"id": "player:1", "pos": Vector2.ZERO, "pinned": true},
		{"id": "building:0", "pos": Vector2(40, 0), "pinned": false},
	]
	var all_kept := NightLights.pick_ids(few, Vector2.ZERO, NightLights.CAP)
	if all_kept.size() != 2:
		printerr("FAIL night_lights_cap under cap kept %s" % all_kept.size())
		fail += 1
	if fail == 0:
		print("PASS test_night_lights_cap")
	return fail
