extends Area2D

var player
# Called when the node enters the scene tree for the first time.
func _ready():
	player = get_node("/root/level/player")
	body_entered.connect(enter)
	
func enter(body):
	if body != player: return
	var error := get_tree().change_scene_to_file("res://scenes/end.tscn")

	if error != OK:
		print("uh oh failed to switch scenes")
