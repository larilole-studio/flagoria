extends RefCounted
## Addresses from successful joins, ordered by most recent connection.

const PATH := "user://saved_servers.cfg"
const SECTION := "multiplayer"
const KEY := "addresses"


static func addresses() -> PackedStringArray:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return PackedStringArray()
	var saved: Variant = config.get_value(SECTION, KEY, PackedStringArray())
	return saved if saved is PackedStringArray else PackedStringArray()


static func remember(address: String) -> void:
	var clean := address.strip_edges()
	if clean.is_empty():
		return
	var saved := addresses()
	var index := saved.find(clean)
	if index >= 0:
		saved.remove_at(index)
	saved.insert(0, clean)
	if _write(saved) != OK:
		push_error("Could not save the joined server.")


static func remove(address: String) -> Error:
	var saved := addresses()
	var index := saved.find(address)
	if index < 0:
		return OK
	saved.remove_at(index)
	return _write(saved)


static func _write(saved: PackedStringArray) -> Error:
	var config := ConfigFile.new()
	config.set_value(SECTION, KEY, saved)
	return config.save(PATH)
