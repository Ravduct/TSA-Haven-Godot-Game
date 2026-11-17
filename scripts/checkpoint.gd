extends Area2D

var player
var respawnPoint
var jello: AnimatedSprite2D
var active = true

func _ready():
	player = get_node("/root/level/player")
	respawnPoint = get_node("/root/level/respawn")
	jello = get_node("hitbox/jello")
	body_entered.connect(on_hit)
	$"hitbox/jello".frame_changed.connect(on_frame)
	
func on_hit(node: Node):
	if node != player || !active: return
	active = false
	respawnPoint.position = self.position
	
	var checkpoint = owner.get_node("CanvasLayer").get_node("checkpointSaved")
	checkpoint.checkout()
	
	jello.play()
	
func on_frame():
	get_node("Bite" + str(randi_range(1, 3))).play()
