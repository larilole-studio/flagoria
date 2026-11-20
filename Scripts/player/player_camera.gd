extends RefCounted
## Sets up local camera zoom and checks full-map visibility.

const MapZoom := preload("res://Scripts/player/map_zoom.gd")


static func attach_zoom(camera: Camera2D) -> void:
	var map_zoom := MapZoom.new()  # local camera only; zoom is never synced
	map_zoom.name = "MapZoom"
	camera.add_child(map_zoom)


static func map_covers_play(tree: SceneTree) -> bool:
	## The parchment full map is open: this hero does not move or attack.
	var node := tree.get_first_node_in_group(ParchmentMap.GROUP)
	return node != null and node.is_open()
