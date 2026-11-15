extends Area2D

var player
var respawnPoint
func _ready():
	player = get_node("/root/Node2D/player")
	respawnPoint = get_node("/root/Node2D/respawn")
	body_entered.connect(on_hit)
	
func on_hit(node: Node):
	if node != player: return
	respawnPoint.position = self.position
