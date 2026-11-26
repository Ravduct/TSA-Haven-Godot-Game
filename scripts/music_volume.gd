extends Node2D
var output
var music_volume

func _ready():
    var slider = get_node("volumeSlide")
    music_volume = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
    output = get_node("volumeNum")

    slider.value_changed.connect(change_value)

func change_value(value: float):
    music_volume = value

    AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), music_volume)

    output.bbcode_enabled = true
    output.text = "[center]" + str(value) + "[/center]"