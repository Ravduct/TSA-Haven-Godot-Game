extends Area2D

func _ready():
	body_exited.connect(on_body_exit)

func on_body_exit(body: Node):
	if body != $slime: return
	$slime.turnaround()
