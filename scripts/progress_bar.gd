extends ProgressBar


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color.DARK_BLUE
	style.set_corner_radius_all(100)
	style.border_width_bottom = 5
	style.border_width_left = 5
	style.border_width_right = 5
	style.border_width_top = 5
	style.border_color = Color.MEDIUM_PURPLE
	self.add_theme_stylebox_override("background", style)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
