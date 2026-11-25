extends Sprite2D

@export var min_time_interval: float = 1.5  # Minimum time between direction changes
@export var max_time_interval: float = 3.0  # Maximum time between direction changes
@export var rotation_speed: float = 2.0     # How fast it eases into the new rotation

var current_target_rotation: float = 0.0
var previous_rotation: float = 0.0
var time_since_change: float = 0.0
var change_interval: float = 2.0
var transition_progress: float = 6.0

func _ready() -> void:
	randomize()
	current_target_rotation = rotation
	previous_rotation = rotation
	pick_new_target()

func _process(delta: float) -> void:
	time_since_change += delta
	
	if time_since_change >= change_interval:
		pick_new_target()
	
	# Progress goes from 0.0 to 1.0 based on rotation speed
	transition_progress = min(transition_progress + delta * rotation_speed, 1.0)
	
	# Apply smoothstep for true ease-in and ease-out interpolation
	var eased_progress = smoothstep(0.0, 1.0, transition_progress)
	
	# Use lerp_angle to smoothly rotate, handling 360-degree wrapping correctly
	rotation = lerp_angle(previous_rotation, current_target_rotation, eased_progress)

func pick_new_target() -> void:
	previous_rotation = rotation
	# Pick a random angle between -180 and 180 degrees (in radians), or full 360
	current_target_rotation = randf_range(-PI, PI)
	
	time_since_change = 0.0
	transition_progress = 0.0
	change_interval = randf_range(min_time_interval, max_time_interval)
