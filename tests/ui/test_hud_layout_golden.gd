extends "res://tests/helpers/test_helpers.gd"

const HudLayoutDump = preload("res://tools/hud_layout_dump.gd")
const GOLDEN := "tests/golden/hud_layout.txt"


func _test_hud_layout_golden() -> int:
	## Time cost: about 1 s in tools/verify.sh.
	print("-- test_hud_layout_golden")
	var actual := await HudLayoutDump.dump(tree)
	var expected := FileAccess.get_file_as_string("res://" + GOLDEN)
	if not actual.is_empty() and actual == expected:
		print("PASS test_hud_layout_golden")
		return 0
	printerr("FAIL hud_layout_golden")
	_print_layout_diff(expected, actual)
	printerr("Regenerate with godot --headless --path . --script res://tools/cli.gd -- hud layout --out " + GOLDEN)
	return 1


func _print_layout_diff(expected: String, actual: String) -> void:
	printerr("--- " + GOLDEN)
	printerr("+++ current HUD layout")
	var before := expected.split("\n", false)
	var after := actual.split("\n", false)
	if before == after:
		printerr("Line endings or blank lines differ.")
		return
	# Both dumps are sorted, so insertions and deletions stay next to their peers.
	var i := 0
	var j := 0
	while i < before.size() or j < after.size():
		if i < before.size() and j < after.size() and before[i] == after[j]:
			i += 1
			j += 1
		elif i < before.size() and (j == after.size() or before[i] < after[j]):
			printerr("-" + before[i])
			i += 1
		else:
			printerr("+" + after[j])
			j += 1
