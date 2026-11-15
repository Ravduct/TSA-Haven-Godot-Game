extends Button

func _ready():
	pressed.connect(on_pressed)

func on_pressed():
	var error := get_tree().change_scene_to_file("res://scenes/level.tscn")

	if error != OK:
		print("uh oh failed to switch scenes")
