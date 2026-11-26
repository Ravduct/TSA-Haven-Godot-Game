extends Button


# Called when the node enters the scene tree for the first time.
func _ready():
	pressed.connect(on_pressed)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func on_pressed():
	#var mainMenu := owner.get_node("Camera2D").global_position
	var camera := owner.get_node("Camera2D")
	
	var tween = create_tween()
	
	tween.tween_property(camera, "global_position", camera.original_position, 1) \
	.set_trans(tween.TRANS_CUBIC) \
	.set_ease(tween.EASE_IN_OUT)
