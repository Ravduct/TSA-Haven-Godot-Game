extends Node2D
var output
var sfx_bus = AudioServer.get_bus_index("SFX")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var slider = get_node("volumeSlide")

	output = get_node("volumeNum")

	slider.value_changed.connect(change_value)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func change_value(value: float) -> void:

	AudioServer.set_bus_volume_db(sfx_bus, value)
	
	output.bbcode_enabled = true
	output.text = "[center]" + str(value) + "[/center]"
	
