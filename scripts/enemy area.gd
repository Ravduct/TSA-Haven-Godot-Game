extends Area2D

var player

func _ready():
	body_exited.connect(on_body_exit)
	body_entered.connect(on_body_enter)
	player = get_node("/root/level/player")

func on_body_exit(body: Node):
	if body != $slime:
		if body == player:
			$slime.speed = 150
			$slime/hitbox/sprite.texture = load("res://image assets/norm.png")
		return
	$slime.turnaround()

func on_body_enter(body: Node):
	if body != player: return
	$slime.speed = 800
	$slime/hitbox/sprite.texture = load("res://image assets/angy.png")
