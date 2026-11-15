extends Node
## Autoload: gameplay settings saved in user settings. The mob spawn rate the
## host uses when it places a world's mobs (see MobSpawner.plan), and the
## tower range, damage and cooldown the host's TowerGuns read.
##
## Only the host spawns mobs and only the host ticks tower guns, so only the
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

## Tests point this at a scratch file.
var save_path := "user://game_settings.cfg"
var mob_rate := MOB_RATE_DEFAULT
var tower_range := TOWER_RANGE_DEFAULT
var tower_damage := TOWER_DAMAGE_DEFAULT
var tower_cooldown := TOWER_COOLDOWN_DEFAULT


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


func save_to_disk() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "mob_rate", mob_rate)
	cfg.set_value(SECTION, "tower_range", tower_range)
	cfg.set_value(SECTION, "tower_damage", tower_damage)
	cfg.set_value(SECTION, "tower_cooldown", tower_cooldown)
	cfg.save(save_path)


func load_from_disk() -> void:
	## Saved values, or defaults for anything missing or not a finite number.
	mob_rate = MOB_RATE_DEFAULT
	tower_range = TOWER_RANGE_DEFAULT
	tower_damage = TOWER_DAMAGE_DEFAULT
	tower_cooldown = TOWER_COOLDOWN_DEFAULT
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
