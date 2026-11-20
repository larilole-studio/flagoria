extends RefCounted
## Binds the local player's health, resources and score to the HUD.

const HUD_LAYER_PATH := "/root/Flagoria/CanvasLayer1"
const POINTS_PATH := "/root/Flagoria/Points"
const INVENTORY_PATH := "/root/Flagoria/Inventory"


static func bind(player: Node, health: PlayerHealth) -> void:
	var hud := _hud_node(player, "HeartsHud")
	if hud:
		hud.bind(health)
	var score_hud := _hud_node(player, "ScoreHud") as ScoreHud
	var points = player.get_node_or_null(POINTS_PATH)
	if score_hud and points:
		score_hud.bind(points, str(player.name).to_int())
	var resource_hud := _hud_node(player, "ResourceHud") as ResourceHud
	var inventory = player.get_node_or_null(INVENTORY_PATH)
	if resource_hud and inventory:
		resource_hud.bind(inventory)
	var plate := _hud_node(player, "StatusPlate") as StatusPlateHud
	if plate != null and hud != null and score_hud != null and resource_hud != null:
		plate.show()
		plate.bind_nodes(hud, score_hud, resource_hud)
	var scoreboard := _hud_node(player, "ScoreboardPanel") as ScoreboardPanel
	var score_toggle := _hud_node(player, "ScoreboardToggle") as ScoreboardToggle
	if scoreboard and points:
		scoreboard.bind(points, str(player.name).to_int())
	if score_toggle:
		score_toggle.show()


static func _hud_node(player: Node, node_name: String) -> Node:
	var layer := player.get_node_or_null(HUD_LAYER_PATH)
	if layer == null:
		return null
	var node := layer.get_node_or_null(node_name)
	if node != null:
		return node
	var plate := layer.get_node_or_null("StatusPlate") as StatusPlateHud
	if plate != null:
		return plate.get_node_or_null(node_name)
	return null
