extends Node2D

var target_spawn_id: String = ""
var is_transitioning: bool = false

var fade_layer: CanvasLayer
var fade_rect: ColorRect

func _ready() -> void:
	# Create a persistent black overlay on top of everything
	fade_layer = CanvasLayer.new()
	fade_layer.layer = 100
	add_child(fade_layer)
	
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.03, 0.03, 0.05, 0.0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade_rect)

func change_scene(scene_path: String, spawn_id: String = "", fade_time: float = 0.4) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	target_spawn_id = spawn_id
	
	# Fade out to black
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, fade_time)
	await tween.finished
	
	# Switch the scene
	get_tree().change_scene_to_file(scene_path)
	
	# Wait one frame for the new scene's nodes to enter the tree
	await get_tree().process_frame
	_position_player_at_spawn()
	
	# Fade back in
	var fade_in := create_tween()
	fade_in.tween_property(fade_rect, "color:a", 0.0, fade_time)
	await fade_in.finished
	is_transitioning = false

func _position_player_at_spawn() -> void:
	if target_spawn_id == "":
		return
	
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
		
	for marker in get_tree().get_nodes_in_group("spawn_points"):
		if marker.name == target_spawn_id and marker is Node2D:
			player.global_position = marker.global_position
			break
