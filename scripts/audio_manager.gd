extends Node

var volumes = {"Music": 50.0, "SFX": 50.0}

func _ready():
    for busName in volumes:
        if AudioServer.get_bus_index(busName) == -1:
            AudioServer.add_bus()
            var index = AudioServer.bus_count - 1
            AudioServer.set_bus_name(index, busName)
            AudioServer.set_bus_send(index, "Master")
        setVolume(busName, volumes[busName])

    get_tree().node_added.connect(assignBus)
    assignAll(get_tree().root)

func assignAll(node: Node):
    assignBus(node)
    for child in node.get_children():
        assignAll(child)

func assignBus(node: Node):
    if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
        if node.bus != "Master":
            return
        if node.is_in_group("music") or node.name.to_lower().contains("music"):
            node.bus = "Music"
        else:
            node.bus = "SFX"

func setVolume(busName: String, value: float):
    var index = AudioServer.get_bus_index(busName)
    volumes[busName] = value
    AudioServer.set_bus_mute(index, value <= 0)
    if value > 0:
        AudioServer.set_bus_volume_db(index, linear_to_db(value / 100.0))

func debugPlayers() -> void:
    for player in get_tree().get_nodes_in_group("debugAudio"):
        pass

func printPlayers(node: Node):
    if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
        print(node.get_path(), " | bus: ", node.bus, " | playing: ", node.playing)
    for child in node.get_children():
        printPlayers(child)