extends Node2D
var output
var music_volume

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass
	var slider = get_node("volumeSlide")
	var title = get_node("title")
	music_volume = owner.get_node("Camera2D").get_node("menu music").volume_db
	output = get_node("volumeNum")
	
	slider.value_changed.connect(change_value)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func change_value(value: float) -> void:
	music_volume = value
	
	var music_player = owner.get_node("Camera2D").get_node("menu music")
	music_player.volume_db = music_volume
	
	output.bbcode_enabled = true
	output.text = "[center]" + str(value) + "[/center]"
