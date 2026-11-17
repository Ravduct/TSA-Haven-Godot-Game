extends Area2D

var player

func _ready():
	player = get_node("/root/level/player")
	body_entered.connect(on_hit)

func on_hit(node: Node):
	if node != player: return
	node.respawn()
