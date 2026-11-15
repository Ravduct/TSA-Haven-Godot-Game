extends Button

func _ready():
	pressed.connect(on_pressed)

func on_pressed():
	var camera := get_parent().get_node("Camera2D")
	var credits := get_parent().get_node("Credits")
	var cameraNode := credits.get_node("background").get_node("cameraNode")
	cameraNode.position.x = credits.position.x + 576
	cameraNode.position.y = credits.position.y + 324

	var tween = create_tween()
	
	tween.tween_property(camera,"position", cameraNode.position, 1) \
	.set_trans(tween.TRANS_CUBIC) \
	.set_ease(tween.EASE_IN_OUT)
	

	
