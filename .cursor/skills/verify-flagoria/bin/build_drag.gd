extends RefCounted


## Drag in window pixels and optionally inspect the game before releasing.
static func drag_touch(
	tree: SceneTree, from: Vector2, to: Vector2, while_dragged := Callable()
) -> void:
	var press := InputEventScreenTouch.new()
	press.position = from
	press.pressed = true
	Input.parse_input_event(press)
	await tree.process_frame
	var drag := InputEventScreenDrag.new()
	drag.position = to
	drag.relative = to - from
	Input.parse_input_event(drag)
	await tree.process_frame
	await tree.process_frame
	if while_dragged.is_valid():
		await while_dragged.call()
	var release := InputEventScreenTouch.new()
	release.position = to
	Input.parse_input_event(release)
	await tree.process_frame
	await tree.process_frame
