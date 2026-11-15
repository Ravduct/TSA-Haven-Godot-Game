extends RichTextLabel


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.hide()
	
func checkout():
	self.show()
	await get_tree().create_timer(2.0).timeout
	self.hide()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
