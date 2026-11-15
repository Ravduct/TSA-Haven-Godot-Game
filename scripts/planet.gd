extends StaticBody2D

@export var spin_speed: float = 0.1  
@export var spin_direction: int = 1  
@export var auto_spin: bool = true   

var _spinning: bool = false

func _ready():
	if auto_spin:
		start_spinning()

func _process(delta):
	if _spinning:
		rotation += spin_direction * spin_speed * delta



func start_spinning():
	_spinning = true

func stop_spinning():
	_spinning = false

func toggle_spinning():
	_spinning = !_spinning


func spin_to(angle_degrees: float, duration: float = 0.3):
	_spinning = false
	var target = rotation + deg_to_rad(angle_degrees)
	var tween = create_tween()
	tween.tween_property(self, "rotation", target, duration)


func spin_forever(duration_per_rotation: float = 1.0):
	_spinning = false
	var tween = create_tween().set_loops()
	tween.tween_property(self, "rotation", rotation + TAU, duration_per_rotation)   
