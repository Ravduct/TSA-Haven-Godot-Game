extends Area2D

var player
var respawnPoint
var jello: AnimatedSprite2D
var active = true

func _ready():
	player = get_node("/root/Node2D/player")
	respawnPoint = get_node("/root/Node2D/respawn")
	jello = get_node("hitbox/jello")
	body_entered.connect(on_hit)
	
func on_hit(node: Node):
	if node != player || !active: return
	active = false
	respawnPoint.position = self.position
	jello.play()
