extends SceneTree
## Headless command line for maps and HUD layout:
##   godot --headless --path . --script res://tools/cli.gd -- map render --seed 42
## Prints to stdout, or writes --out.

const HudLayoutDump = preload("res://tools/hud_layout_dump.gd")
const USAGE := """usage: godot --headless --path . --script res://tools/cli.gd -- <command> [options]
  map render [--params <file>|default] [--seed <n>] [--format ascii] [--out <path>]
  map stats  [--params <file>|default] [--seed <n>] [--out <path>]
  hud layout [--out <path>]
--params: a map save (.json, see MapSave) or "default" (the default).
--seed n: altitude, moisture, temperature, items and biome seeds n .. n+4.
Without --seed every seed must come from --params.
Exit codes: 0 ok, 1 error, 2 bad usage."""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.slice(0, 2) == PackedStringArray(["hud", "layout"]):
		if args.size() != 2 and (args.size() != 4 or args[2] != "--out"
				or args[3].is_empty() or args[3].begins_with("--")):
			printerr("error: expected hud layout [--out <path>]")
			quit(2)
			return
		var snapshot := await HudLayoutDump.dump(self)
		var out := args[3] if args.size() == 4 else ""
		quit(1 if snapshot.is_empty() else _write_output(snapshot, out))
		return
	var parsed := MapCli.parse(args)
	if parsed["error"] != "":
		printerr("error: %s\n%s" % [parsed["error"], USAGE])
		quit(2)
		return
	var options: Dictionary = parsed["options"]
	var resolved := MapCli.params_for(options["params"], options["seed"])
	if resolved["error"] != "":
		printerr("error: " + resolved["error"])
		quit(1)
		return
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var rows := MapCli.generate(scene.get_node("World/worldMap"), resolved["params"])
	var text := MapCli.ascii(rows) if parsed["command"] == "map render" else MapCli.stats(rows)
	scene.queue_free()
	quit(_write_output(text, options["out"]))


func _write_output(text: String, path: String) -> int:
	if path.is_empty():
		printraw(text)
		return 0
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("error: cannot write %s (error %s)" % [path, FileAccess.get_open_error()])
		return 1
	file.store_string(text)
	return 0
