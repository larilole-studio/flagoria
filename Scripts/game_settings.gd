extends Node
## Autoload: gameplay settings saved in user settings. The mob spawn rate is
## what the host uses when it places a world's mobs (see MobSpawner.plan).
## Raid tunables drive RaidDirector. Raids stay off until a host turns them on.
##
## Only the host spawns mobs and runs raids, so only the host's values matter
## in multiplayer; a client's saved settings are never read during a match.

const SECTION := "gameplay"
## Multiplier on MobSpawner's base density and caps. 1.0 was the only rate
## before the setting existed.
const MOB_RATE_DEFAULT := 2.0
const MOB_RATE_MIN := 0.5
const MOB_RATE_MAX := 3.0
const MOB_RATE_STEP := 0.25
## Raid clock. Off until a play-test turns it on (#529).
const RAID_INTERVAL_DEFAULT := 45.0
const RAID_INTERVAL_MIN := 15.0
const RAID_INTERVAL_MAX := 180.0
const RAID_INTERVAL_STEP := 1.0
const RAID_GROUP_DEFAULT := 3
const RAID_GROUP_MIN := 1
const RAID_GROUP_MAX := 8
const RAID_RADIUS_DEFAULT := 48
const RAID_RADIUS_MIN := 16
const RAID_RADIUS_MAX := 96

## Tests point this at a scratch file.
var save_path := "user://game_settings.cfg"
var mob_rate := MOB_RATE_DEFAULT
var raids_enabled := false
var raid_interval_s := RAID_INTERVAL_DEFAULT
var raid_group := RAID_GROUP_DEFAULT
var raid_radius_cells := RAID_RADIUS_DEFAULT


func _ready() -> void:
	load_from_disk()


func set_mob_rate(value: float, save := true) -> void:
	mob_rate = clampf(snappedf(value, MOB_RATE_STEP), MOB_RATE_MIN, MOB_RATE_MAX)
	if save:
		save_to_disk()


func set_raids_enabled(value: bool, save := true) -> void:
	raids_enabled = value
	if save:
		save_to_disk()


func set_raid_interval_s(value: float, save := true) -> void:
	raid_interval_s = clampf(snappedf(value, RAID_INTERVAL_STEP), RAID_INTERVAL_MIN, RAID_INTERVAL_MAX)
	if save:
		save_to_disk()


func set_raid_group(value: int, save := true) -> void:
	raid_group = clampi(value, RAID_GROUP_MIN, RAID_GROUP_MAX)
	if save:
		save_to_disk()


func set_raid_radius_cells(value: int, save := true) -> void:
	raid_radius_cells = clampi(value, RAID_RADIUS_MIN, RAID_RADIUS_MAX)
	if save:
		save_to_disk()


func save_to_disk() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "mob_rate", mob_rate)
	cfg.set_value(SECTION, "raids_enabled", raids_enabled)
	cfg.set_value(SECTION, "raid_interval_s", raid_interval_s)
	cfg.set_value(SECTION, "raid_group", raid_group)
	cfg.set_value(SECTION, "raid_radius_cells", raid_radius_cells)
	cfg.save(save_path)


func load_from_disk() -> void:
	## Saved values, or defaults for anything missing or not a finite number.
	mob_rate = MOB_RATE_DEFAULT
	raids_enabled = false
	raid_interval_s = RAID_INTERVAL_DEFAULT
	raid_group = RAID_GROUP_DEFAULT
	raid_radius_cells = RAID_RADIUS_DEFAULT
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	var v: Variant = cfg.get_value(SECTION, "mob_rate", MOB_RATE_DEFAULT)
	if (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT) and is_finite(float(v)):
		set_mob_rate(float(v), false)
	var enabled: Variant = cfg.get_value(SECTION, "raids_enabled", false)
	if enabled is bool:
		set_raids_enabled(enabled, false)
	var interval: Variant = cfg.get_value(SECTION, "raid_interval_s", RAID_INTERVAL_DEFAULT)
	if (typeof(interval) == TYPE_INT or typeof(interval) == TYPE_FLOAT) and is_finite(float(interval)):
		set_raid_interval_s(float(interval), false)
	var group: Variant = cfg.get_value(SECTION, "raid_group", RAID_GROUP_DEFAULT)
	if typeof(group) == TYPE_INT or typeof(group) == TYPE_FLOAT:
		set_raid_group(int(group), false)
	var radius: Variant = cfg.get_value(SECTION, "raid_radius_cells", RAID_RADIUS_DEFAULT)
	if typeof(radius) == TYPE_INT or typeof(radius) == TYPE_FLOAT:
		set_raid_radius_cells(int(radius), false)


static func rate_label(value: float) -> String:
	## "2x", "1.5x", "0.75x".
	var text := "%.2f" % value
	return text.rstrip("0").rstrip(".") + "x"
