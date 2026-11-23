class_name HeartsHud
extends Control
## A row of half-step hearts for the local player's health.

const SPACING := 1
const MARGIN := 4
const FLASH_FRAME := 0.06  ## seconds each flash icon is shown

var current := 0
var maximum := 0
var _flash_slots: Array[int] = []
var _flash_time := -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = RoundHudStyle.FILTER
	position = Vector2(MARGIN, MARGIN)


func bind(health: PlayerHealth) -> void:
	## Follow one player's health and show the row.
	health.health_changed.connect(set_health)
	# A late copy's state reply is not a loss happening now: no flash.
	health.state_received.connect(set_health.bind(false))
	set_health(health.health, health.max_health)
	show()


func set_health(value: int, max_value: int, flash := true) -> void:
	## `flash` false shows the new value with no loss flash.
	if flash and max_value == maximum and value < current:
		_flash_slots.clear()
		for i in ceili(maximum / 2.0):
			if icon_for(i, value) != icon_for(i, current):
				_flash_slots.append(i)
		_flash_time = 0.0
	current = value
	maximum = max_value
	var n := ceili(maximum / 2.0)
	var heart := RoundHudStyle.texture("heart_full")
	custom_minimum_size = Vector2(
		maxi(n * (heart.get_width() + SPACING) - SPACING, 0), heart.get_height()
	)
	size = custom_minimum_size
	queue_redraw()


static func icon_for(slot: int, value: int) -> Texture2D:
	## Heart `slot` (0 = leftmost) when health is `value` half-hearts.
	var left := value - slot * 2
	if left >= 2:
		return RoundHudStyle.texture("heart_full")
	if left == 1:
		return RoundHudStyle.texture("heart_half")
	return RoundHudStyle.texture("heart_empty")


func shown_icon(slot: int) -> Texture2D:
	## The icon drawn in `slot` right now, including a loss flash.
	if _flash_time >= 0.0 and slot in _flash_slots:
		return (
			RoundHudStyle.texture("heart_flash_0")
			if _flash_time < FLASH_FRAME
			else RoundHudStyle.texture("heart_flash_1")
		)
	return icon_for(slot, current)


func advance(delta: float) -> void:
	## Step the loss flash; it ends after two FLASH_FRAMEs.
	if _flash_time < 0.0:
		return
	_flash_time += delta
	if _flash_time >= FLASH_FRAME * 2.0:
		_flash_time = -1.0
		_flash_slots.clear()
	queue_redraw()


func _process(delta: float) -> void:
	advance(delta)


func _draw() -> void:
	var step := RoundHudStyle.texture("heart_full").get_width() + SPACING
	for i in ceili(maximum / 2.0):
		draw_texture(shown_icon(i), Vector2(i * step, 0))
