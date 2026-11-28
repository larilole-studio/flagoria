class_name BuildingAlerts
extends Control
## Short-lived owner-only alerts shared by the HUD minimap and parchment map.

const WorldMap := preload("res://Scripts/world/TileMap.gd")
const ALERT_SECONDS := 5.0
const MAP_SIZE := Vector2(108, 56)
const MAP_TOP := Vector2(2, 14)
const CELL_PX := 4
const INK := Color("#2a2238")
const PAPER := Color("#e8c968")
const RED := Color("#e04a4a")
const GOLD := Color("#ffe680")
const FONT := preload("res://art/ui/fonts/LilitaOne-Regular.ttf")

var _alerts := {}
var _latest := 0

@onready var _chart: MapChart = $"../MapChart"
@onready var _map: WorldMap = $"../../World/worldMap"
@onready var _health: BuildingHealth = $"../../World/BuildingHealth"


func _ready() -> void:
	_health.building_damaged.connect(_on_damaged)
	_chart.chart_cleared.connect(clear)
	get_viewport().size_changed.connect(_layout)
	_layout()
	clear()


func _on_damaged(id: int, owner: int, _hp: int) -> void:
	if not multiplayer.is_server() or owner < 1:
		return
	var placement := _map._structures.placement_details(id)
	if placement.is_empty():
		return
	var cell: Vector2i = placement["anchor"]
	var building: String = placement["name"]
	if owner == multiplayer.get_unique_id():
		record_alert(id, cell, building)
	elif owner in multiplayer.get_peers():
		receive_alert.rpc_id(owner, id, cell, building)


@rpc("authority", "call_remote", "reliable")
func receive_alert(id: int, cell: Vector2i, building: String) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		record_alert(id, cell, building)


func record_alert(id: int, cell: Vector2i, building: String) -> void:
	_alerts[id] = {"cell": cell, "building": building, "left": ALERT_SECONDS}
	_latest = id
	show()
	set_process(true)


func alert_count() -> int:
	return _alerts.size()


func clear() -> void:
	_alerts.clear()
	_latest = 0
	hide()
	set_process(false)


func advance(delta: float) -> void:
	for id in _alerts.keys():
		var marker: Dictionary = _alerts[id]
		marker["left"] -= delta
		if marker["left"] <= 0.0:
			_alerts.erase(id)
	if _alerts.is_empty():
		clear()


func _process(delta: float) -> void:
	advance(delta)
	queue_redraw()


func _layout() -> void:
	position = Vector2(roundf(get_viewport_rect().size.x - MAP_SIZE.x - 14), 43)
	size = Vector2(MAP_SIZE.x + 4, MAP_SIZE.y + 16)


func _draw() -> void:
	if _alerts.is_empty():
		return
	var latest: Dictionary = _alerts[_latest]
	var origin := _map_position(latest["cell"], CELL_PX) - MAP_SIZE * 0.5
	var bounds := Rect2(origin, MAP_SIZE)
	draw_rect(Rect2(Vector2.ZERO, size), INK)
	draw_rect(Rect2(MAP_TOP, MAP_SIZE), MapChart.SKY_DEEP)
	draw_string(
		FONT,
		Vector2(3, 10),
		_alert_title(latest["building"]),
		HORIZONTAL_ALIGNMENT_CENTER,
		MAP_SIZE.x - 2,
		9,
		PAPER
	)
	var chart_scale := float(CELL_PX) / MapChart.CELL_PX
	var chunk_px := ExploredMap.CHUNK * CELL_PX
	var first := Vector2i((bounds.position / float(chunk_px)).floor())
	var last := Vector2i((bounds.end / float(chunk_px)).floor())
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var chunk := Vector2i(x, y)
			var texture := _chart.chunk_texture(chunk)
			if texture == null:
				continue
			var at := Vector2(chunk * chunk_px)
			var clipped := Rect2(at, Vector2.ONE * chunk_px).intersection(bounds)
			if clipped.has_area():
				draw_texture_rect_region(
					texture,
					Rect2(clipped.position - origin + MAP_TOP, clipped.size),
					Rect2((clipped.position - at) / chart_scale, clipped.size / chart_scale)
				)
	draw_markers(self, origin, CELL_PX, Rect2(MAP_TOP, MAP_SIZE))


func draw_markers(canvas: CanvasItem, origin: Vector2, cell_px: int, bounds: Rect2) -> void:
	for alert: Dictionary in _alerts.values():
		var at := (_map_position(alert["cell"], cell_px) - origin + bounds.position).round()
		if not bounds.grow(-6).has_point(at):
			continue
		var left: float = alert["left"]
		var opacity := minf(1.0, left)
		var radius := 4.0 + floorf(fmod(left * 4.0, 3.0))
		canvas.draw_arc(at, radius, 0.0, TAU, 16, Color(GOLD, opacity), 1.0)
		canvas.draw_rect(Rect2(at - Vector2(3, 4), Vector2(7, 9)), Color(INK, opacity))
		canvas.draw_rect(Rect2(at - Vector2(2, 3), Vector2(5, 7)), Color(RED, opacity))
		canvas.draw_rect(Rect2(at - Vector2(0, 2), Vector2(1, 3)), Color(GOLD, opacity))
		canvas.draw_rect(Rect2(at + Vector2(0, 2), Vector2.ONE), Color(GOLD, opacity))


func _map_position(cell: Vector2i, cell_px: int) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * cell_px


func _alert_title(building: String) -> String:
	var name_text := "Tower" if building == "tower_wood" else building.capitalize()
	return "%s under attack" % name_text
