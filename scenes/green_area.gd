extends Area2D

var player

func _ready():
	body_exited.connect(on_body_exit)
	player = get_node("/root/Node2D/player")

func on_body_exit(body: Node):
	if body != $slime: return
	$slime.turnaround()
