extends Button


# Called when the node enters the scene tree for the first time.
func _ready():
	pressed.connect(on_pressed)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func on_pressed():
	var camera := get_node("/root/Node2D/Camera2D")
	var cameraNode := get_node("/root/Node2D/Settings/background/cameraNode")
	
	var tween := create_tween()
	
	tween.tween_property(camera, "position", cameraNode.global_position, 1) \
	.set_trans(tween.TRANS_CUBIC) \
	.set_ease(tween.EASE_IN_OUT)
