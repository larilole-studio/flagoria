extends Node
## Host-owned day/night clock (#558).
##
## A 600 second cycle: 6 minutes of day, 1 of dusk, 2 of night, 1 of dawn.
## Dusk and dawn are 15 seconds of smoothstep, a 30 second hold, then 15
## seconds into the next key. Tints are the sRGB multipliers in
## docs/day_night.json. The CanvasModulate sits on the default canvas, so
## the HUD CanvasLayers stay at full brightness. Clients and a late joiner
## are sent the host's elapsed time.

const _NightLights := preload("res://Scripts/mechanics/day_night/night_lights.gd")

const CYCLE_SECONDS := 600.0
## How often the host repeats the elapsed time. A peer coasts between
## messages, so it stays within one tint step of the host.
const SYNC_SECONDS := 0.25

const TINT_DAY := "#ffffff"
const TINT_DUSK := "#eba684"
const TINT_NIGHT := "#808cc8"
const TINT_DAWN := "#e8b4c8"

## Segment lengths, in order, from docs/day_night.json "timing".
const SEGMENT_SECONDS: Array[float] = [
	360.0,
	15.0,
	30.0,
	15.0,
	120.0,
	15.0,
	30.0,
	15.0,
]
const SEGMENT_FROM: Array[String] = [
	"day",
	"day",
	"dusk",
	"dusk",
	"night",
	"night",
	"dawn",
	"dawn",
]
const SEGMENT_TO: Array[String] = [
	"day",
	"dusk",
	"dusk",
	"night",
	"night",
	"dawn",
	"dawn",
	"day",
]
## Named windows: day 6 min, dusk 1, night 2, dawn 1.
const PHASE_END: Array[float] = [360.0, 420.0, 540.0, 600.0]
const PHASE_NAME: Array[String] = ["day", "dusk", "night", "dawn"]
## Middle of each hold, where the tint is that key with no blend.
const PHASE_HOLD := {
	"day": 180.0,
	"dusk": 390.0,
	"night": 480.0,
	"dawn": 570.0,
}

## Seconds into the cycle, in [0, CYCLE_SECONDS).
var elapsed := 0.0
## Map Settings switch. Off keeps the tint at day.
var enabled := true
## True once this peer has the host clock (the host itself, or a received sync).
var synced := false

var _running := false
var _following := false
var _sync_wait := 0.0
var _modulate: CanvasModulate
## Peers that connected inside the peer_connected signal. The clock is sent
## on the next frame, after the host has finished spawning that peer.
var _pending_peers: Array[int] = []


func _ready() -> void:
	_modulate = CanvasModulate.new()
	_modulate.name = "WorldTint"
	add_child(_modulate)
	# Local pools (#560). The child creates nothing and does no per-frame work
	# on a headless host; a display peer draws from state it already has.
	var lights := _NightLights.new()
	lights.name = "NightLights"
	add_child(lights)
	_apply_tint()
	multiplayer.peer_connected.connect(_on_peer_connected)


func begin(params: MapGenParams, at: float) -> void:
	## A match is starting. `at` is the saved elapsed time, or 0 for a new
	## world and for an older save that has no clock.
	enabled = params.day_night_cycle
	elapsed = cycle_wrap(at)
	_running = true
	_following = false
	synced = true
	_sync_wait = 0.0
	_pending_peers.clear()
	_apply_tint()
	_broadcast()


func stop() -> void:
	_running = false
	_following = false
	synced = false
	enabled = true
	elapsed = 0.0
	_pending_peers.clear()
	_apply_tint()


func seek_phase(phase: String) -> bool:
	## Jump to the middle of that phase's hold. The host tells peers at once.
	if not PHASE_HOLD.has(phase):
		return false
	elapsed = float(PHASE_HOLD[phase])
	_apply_tint()
	_broadcast()
	return true


func tick(delta: float) -> void:
	## Advance one step. With the cycle off the clock stays put and the tint
	## stays at day.
	if enabled:
		elapsed = cycle_wrap(elapsed + delta)
	_apply_tint()


func phase() -> String:
	if not enabled:
		return "day"
	return phase_at(elapsed)


func spawn_scale() -> float:
	## Ambient mob caps. The host and a joiner both call this: it is 1 with
	## the cycle off or in the day hold, 2 in the night hold, and the dusk
	## and dawn smoothstep in between. Not used from _process.
	return spawn_scale_for(elapsed, enabled)


func displayed_tint() -> Color:
	if not enabled:
		return color_of("day")
	return tint_at(elapsed)


func report() -> Dictionary:
	## What a peer is showing, for the sync probe.
	var tint := _modulate.color if _modulate != null else displayed_tint()
	return {
		"phase": phase(),
		"elapsed": elapsed,
		"enabled": enabled,
		"synced": synced,
		"tint": [tint.r, tint.g, tint.b],
	}


func _process(delta: float) -> void:
	if not _running:
		return
	if _hosting():
		_read_switch()
		tick(delta)
		_flush_pending()
		_sync_wait += delta
		if _sync_wait >= SYNC_SECONDS:
			_sync_wait = 0.0
			_broadcast()
	elif _following:
		tick(delta)
	else:
		_apply_tint()


func _read_switch() -> void:
	## Map Settings writes the live params. Follow that switch on the host.
	var map_gen := get_node_or_null("/root/MapGen")
	if map_gen == null:
		return
	var on := bool(map_gen.params.day_night_cycle)
	if on == enabled:
		return
	enabled = on
	var game := get_node_or_null("/root/Flagoria")
	if game != null:
		var live: Variant = game.get("world_params")
		if live is MapGenParams:
			(live as MapGenParams).day_night_cycle = on
	_broadcast()


func _on_peer_connected(id: int) -> void:
	## Do not rpc from inside this signal. The host still has to spawn the
	## peer and send the map on the same callback; a clock message here can
	## stall that join on a slow host.
	if _running and _hosting():
		_pending_peers.append(id)


func _flush_pending() -> void:
	if _pending_peers.is_empty() or not _hosting():
		return
	var ids: Array[int] = []
	ids.assign(_pending_peers)
	_pending_peers.clear()
	var connected := multiplayer.get_peers()
	for id in ids:
		if connected.has(id):
			rpc_id(id, "receive_clock", elapsed, enabled)


func _broadcast() -> void:
	if not _hosting() or multiplayer.get_peers().is_empty():
		return
	rpc("receive_clock", elapsed, enabled)


func _hosting() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer is ENetMultiplayerPeer and multiplayer.is_server()


@rpc("authority", "reliable", "call_remote")
func receive_clock(at: float, cycle_on: bool) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	enabled = cycle_on
	elapsed = cycle_wrap(at)
	_running = true
	_following = true
	synced = true
	_apply_tint()


func _apply_tint() -> void:
	## Setting the colour every frame dirties the canvas. Headless hosts that
	## do that from _process stop polling the network, so a join never finishes.
	## Day holds one colour for minutes; write only when it changes.
	if _modulate == null:
		return
	var next := displayed_tint()
	if _modulate.color == next:
		return
	_modulate.color = next


static func cycle_wrap(seconds: float) -> float:
	if is_nan(seconds) or is_inf(seconds):
		return 0.0
	return fposmod(seconds, CYCLE_SECONDS)


static func cycle_ease(t: float) -> float:
	## t * t * (3 - 2 * t), the ease in docs/day_night.json.
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


static func night_weight(seconds: float) -> float:
	## 0 through the day hold, smoothstep across the dusk window, 1 through
	## the night hold, smoothstep back to 0 across dawn. Same seconds the
	## phase and the tint use.
	var t := cycle_wrap(seconds)
	var day_end := PHASE_END[0]
	var dusk_end := PHASE_END[1]
	var night_end := PHASE_END[2]
	if t < day_end:
		return 0.0
	if t < dusk_end:
		return cycle_ease((t - day_end) / (dusk_end - day_end))
	if t < night_end:
		return 1.0
	return 1.0 - cycle_ease((t - night_end) / (CYCLE_SECONDS - night_end))


static func spawn_scale_for(seconds: float, cycle_on: bool) -> float:
	if not cycle_on:
		return 1.0
	return 1.0 + night_weight(seconds)


static func color_of(phase: String) -> Color:
	match phase:
		"dusk":
			return Color.html(TINT_DUSK)
		"night":
			return Color.html(TINT_NIGHT)
		"dawn":
			return Color.html(TINT_DAWN)
		_:
			return Color.html(TINT_DAY)


static func phase_at(seconds: float) -> String:
	var t := cycle_wrap(seconds)
	for i in PHASE_END.size():
		if t < PHASE_END[i]:
			return PHASE_NAME[i]
	return "day"


static func tint_at(seconds: float) -> Color:
	## sRGB Color.lerp. Holds return the key. Eases use smoothstep.
	var seg := _segment(seconds)
	var from := color_of(str(seg["from"]))
	var to := color_of(str(seg["to"]))
	if seg["from"] == seg["to"]:
		return from
	return from.lerp(to, cycle_ease(float(seg["u"])))


static func _segment(seconds: float) -> Dictionary:
	var t := cycle_wrap(seconds)
	var cursor := 0.0
	for i in SEGMENT_SECONDS.size():
		var length := SEGMENT_SECONDS[i]
		var last := i == SEGMENT_SECONDS.size() - 1
		if t < cursor + length or last:
			var u := 0.0
			if length > 0.0:
				u = clampf((t - cursor) / length, 0.0, 1.0)
			return {"from": SEGMENT_FROM[i], "to": SEGMENT_TO[i], "u": u}
		cursor += length
	return {"from": "day", "to": "day", "u": 0.0}
