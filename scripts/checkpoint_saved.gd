extends RichTextLabel


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.hide()
	
func checkout():
	self.show()
	await get_tree().create_timer(2.0).timeout
	self.hide()
