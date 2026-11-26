extends Sprite2D

@export var rotation_speed: float = 0.02 

func _process(delta: float) -> void:
	rotation += rotation_speed * delta
