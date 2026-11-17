extends Node2D
var output
var music_volume

func _ready():
    var slider = get_node("volumeSlide")
    music_volume = owner.get_node("Camera2D").get_node("menu music").volume_db
    output = get_node("volumeNum")

    slider.value_changed.connect(change_value)

func change_value(value: float):
    music_volume = value

    var music_player = owner.get_node("Camera2D").get_node("menu music")
    music_player.volume_db = music_volume

    output.bbcode_enabled = true
    output.text = "[center]" + str(value) + "[/center]"