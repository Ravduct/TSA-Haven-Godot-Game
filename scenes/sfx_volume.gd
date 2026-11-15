extends Node2D
var output
var music_volume

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var slider = get_node("volumeSlide")
	music_volume = owner.get_node("Camera2D").get_node("menu music").volume_db
	output = get_node("volumeNum")
	
	slider.value_changed.connect(change_value)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func change_value(value: float) -> void:
	music_volume = value
	
	var jelly_land = load("res://audio/jelly land.mp3")
	var mov = load("res://audio/mov.mp3")
	
	jelly_land.music_volume = music_volume
	mov.music_volume = music_volume
	
	output.bbcode_enabled = true
	output.text = "[center]" + str(value) + "[/center]"
