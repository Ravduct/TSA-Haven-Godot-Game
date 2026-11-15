extends CPUParticles2D

var on = true
func toggle():
	on = !on
	$"hitbox/hitbox".disabled = !on
	emitting = on
	$Timer.wait_time = randf_range(5, 10)

func _physics_process(delta: float) -> void:
	if on:
		for i in $hitbox.get_overlapping_bodies():
			i.velocity.y -= 120

func _ready():
	toggle()
	$Timer.timeout.connect(toggle)
