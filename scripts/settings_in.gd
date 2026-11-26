extends Button



func _ready():
	pressed.connect(on_pressed)


#
func on_pressed():
	var camera := get_node("/root/menu/Camera2D")
	var cameraNode := get_node("/root/menu/Settings/background/cameraNode")
	
	var tween := create_tween()
	
	tween.tween_property(camera, "position", cameraNode.global_position, 1) \
	.set_trans(tween.TRANS_CUBIC) \
	.set_ease(tween.EASE_IN_OUT)
