extends Node
## Autoload: gameplay settings saved in user settings. The mob spawn rate is
## what the host uses when it places a world's mobs (see MobSpawner.plan).
## Raid tunables drive RaidDirector. Raids stay off until a host turns them on.
## Tower range, damage and cooldown are what the host's TowerGuns read.
##
## Only the host spawns mobs, runs raids, and ticks tower guns, so only the
## host's saved values matter in a match. A client's file is never the match.

const SECTION := "gameplay"
## Multiplier on MobSpawner's base density and caps. 1.0 was the only rate
## before the setting existed.
const MOB_RATE_DEFAULT := 2.0
const MOB_RATE_MIN := 0.5
const MOB_RATE_MAX := 3.0
const MOB_RATE_STEP := 0.25
## TowerGuns. Pixels, half-hearts, and seconds. The steps hit the defaults.
const TOWER_RANGE_DEFAULT := 80.0
const TOWER_RANGE_MIN := 32.0
const TOWER_RANGE_MAX := 160.0
const TOWER_RANGE_STEP := 8.0
const TOWER_DAMAGE_DEFAULT := 1
const TOWER_DAMAGE_MIN := 1
const TOWER_DAMAGE_MAX := 3
const TOWER_COOLDOWN_DEFAULT := 1.5
const TOWER_COOLDOWN_MIN := 0.5
const TOWER_COOLDOWN_MAX := 5.0
const TOWER_COOLDOWN_STEP := 0.1
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
var tower_range := TOWER_RANGE_DEFAULT
var tower_damage := TOWER_DAMAGE_DEFAULT
var tower_cooldown := TOWER_COOLDOWN_DEFAULT
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


func set_tower_range(value: float, save := true) -> void:
	tower_range = clampf(snappedf(value, TOWER_RANGE_STEP), TOWER_RANGE_MIN, TOWER_RANGE_MAX)
	if save:
		save_to_disk()


func set_tower_damage(value: float, save := true) -> void:
	tower_damage = clampi(roundi(value), TOWER_DAMAGE_MIN, TOWER_DAMAGE_MAX)
	if save:
		save_to_disk()


func set_tower_cooldown(value: float, save := true) -> void:
	tower_cooldown = clampf(snappedf(value, TOWER_COOLDOWN_STEP), TOWER_COOLDOWN_MIN, TOWER_COOLDOWN_MAX)
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
	cfg.set_value(SECTION, "tower_range", tower_range)
	cfg.set_value(SECTION, "tower_damage", tower_damage)
	cfg.set_value(SECTION, "tower_cooldown", tower_cooldown)
	cfg.set_value(SECTION, "raids_enabled", raids_enabled)
	cfg.set_value(SECTION, "raid_interval_s", raid_interval_s)
	cfg.set_value(SECTION, "raid_group", raid_group)
	cfg.set_value(SECTION, "raid_radius_cells", raid_radius_cells)
	cfg.save(save_path)


func load_from_disk() -> void:
	## Saved values, or defaults for anything missing or not a finite number.
	mob_rate = MOB_RATE_DEFAULT
	tower_range = TOWER_RANGE_DEFAULT
	tower_damage = TOWER_DAMAGE_DEFAULT
	tower_cooldown = TOWER_COOLDOWN_DEFAULT
	raids_enabled = false
	raid_interval_s = RAID_INTERVAL_DEFAULT
	raid_group = RAID_GROUP_DEFAULT
	raid_radius_cells = RAID_RADIUS_DEFAULT
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	var rate: Variant = cfg.get_value(SECTION, "mob_rate", MOB_RATE_DEFAULT)
	if (typeof(rate) == TYPE_INT or typeof(rate) == TYPE_FLOAT) and is_finite(float(rate)):
		set_mob_rate(float(rate), false)
	var reach: Variant = cfg.get_value(SECTION, "tower_range", TOWER_RANGE_DEFAULT)
	if (typeof(reach) == TYPE_INT or typeof(reach) == TYPE_FLOAT) and is_finite(float(reach)):
		set_tower_range(float(reach), false)
	var harm: Variant = cfg.get_value(SECTION, "tower_damage", TOWER_DAMAGE_DEFAULT)
	if (typeof(harm) == TYPE_INT or typeof(harm) == TYPE_FLOAT) and is_finite(float(harm)):
		set_tower_damage(float(harm), false)
	var wait: Variant = cfg.get_value(SECTION, "tower_cooldown", TOWER_COOLDOWN_DEFAULT)
	if (typeof(wait) == TYPE_INT or typeof(wait) == TYPE_FLOAT) and is_finite(float(wait)):
		set_tower_cooldown(float(wait), false)
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


static func px_label(value: float) -> String:
	return "%d px" % roundi(value)


static func seconds_label(value: float) -> String:
	## "1.5 s", "2 s", "0.5 s".
	var text := "%.1f" % value
	return text.rstrip("0").rstrip(".") + " s"