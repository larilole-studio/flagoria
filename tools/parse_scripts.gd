extends SceneTree
## Compile every GDScript path in a list file, in this one process.

class _ScriptErrors extends Logger:
	var count := 0

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_SCRIPT:
			count += 1
##
## tools/verify.sh used to start Godot once per file (`--check-only --script`).
## Engine startup dominated that step. This script compiles the same set and
## exits 1 when any file fails to load. A parse error still prints
## `SCRIPT ERROR`, which verify.sh treats as a failure.
##
## Run: godot --headless --path . --script res://tools/parse_scripts.gd -- --list=/path/to/files.txt
## The list is repo-relative paths, one per line (the same set `find` used).


func _initialize() -> void:
	var list_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--list="):
			list_path = arg.trim_prefix("--list=")
	if list_path == "":
		printerr("parse_scripts: pass --list=FILE (one repo-relative .gd path per line)")
		quit(1)
		return
	if not FileAccess.file_exists(list_path):
		printerr("parse_scripts: list file not found")
		quit(1)
		return
	var errors := _ScriptErrors.new()
	OS.add_logger(errors)
	var fail := 0
	var count := 0
	for raw in FileAccess.get_file_as_string(list_path).split("\n"):
		var rel := raw.strip_edges()
		if rel == "" or rel.begins_with("#"):
			continue
		count += 1
		var res := "res://" + rel.trim_prefix("./")
		var before := errors.count
		var script = load(res)
		# load() can return a GDScript object even when the file did not compile.
		if script == null or not (script is GDScript) or errors.count > before:
			printerr("parse failed: %s" % res)
			fail += 1
	if count == 0:
		printerr("parse_scripts: the list was empty")
		quit(1)
		return
	if fail > 0:
		printerr("Script parse: %d of %d file(s) failed" % [fail, count])
		quit(1)
		return
	print("Script parse: ok (%d files)" % count)
	quit(0)
