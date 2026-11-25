extends CharacterBody2D

@export var speed = 100
@export var sprint = 200
@export var air_speed = 10
@export var current_speed = speed
@export var speed_modifier = 0

@export var jump_power = 700
@export var current_jump_power = jump_power
@export var jump_power_modifier = 0

@export var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
@export var current_gravity = gravity
@export var gravity_modifier = 0

@export var friction = 0.8
@export var air_friction = 0.99
@export var side_friction = 1
@export var current_friction = friction
@export var friction_modifier = 0

signal health_changed(new_health: float)
@export var health : float = 100.0:
	set(value):
		health = value
		print("health changed")
		health_changed.emit(health)

@export var state = PlayerState.IDLE
@export var on_floor = false
@export var on_ceiling = false
@export var stuck_to_ceiling = false
@export var spawn_position = null

signal StateChanged
enum PlayerState {
	IDLE,
	WALL,
	WALKING,
	RUNNING,
	JUMPING,
	FALLING,
	CLIMBING,
	LOWERING,
	LAND,
	CEILING,
	DEATH
}

func on_state_change(s):
	s = PlayerState.find_key(s)
	print(s)

func evaulateState():
	var last = state
	var delta = get_position_delta()
	if delta.length() <= 0.1:
		state = PlayerState.WALL if side_friction == 0.5 else PlayerState.IDLE
	elif delta.x != 0:
		if abs(delta.x) <= 10:
			state = PlayerState.WALKING
		else:
			state = PlayerState.RUNNING
	
	if !on_floor:
		if delta.y < 0:
			state = PlayerState.CLIMBING if side_friction == 0.5 else PlayerState.JUMPING
		elif delta.y > 0.1:
			state = PlayerState.LOWERING if side_friction == 0.5 else PlayerState.FALLING
		if on_ceiling:
			state = PlayerState.CEILING
	elif last == PlayerState.FALLING:
		state = PlayerState.LAND
	
	if health <= 0:
		state = PlayerState.DEATH
	
	if state != last:
		StateChanged.emit(state)

func get_tile_type(layer: TileMapLayer, world_pos: Vector2) -> String:
	if layer.tile_set == null or not layer.tile_set.has_custom_data_layer_by_name("type"):
		return ""
	var cell := layer.local_to_map(layer.to_local(world_pos))
	var data := layer.get_cell_tile_data(cell)
	if data == null:
		return ""
	var value = data.get_custom_data("type")
	return value if value is String else ""

func _ready():
	spawn_position = self.global_position
	StateChanged.connect(on_state_change)

func _physics_process(delta: float):
	if !on_floor:
		current_friction = air_friction
		current_speed = air_speed
	else:
		current_friction = friction
		current_speed = sprint if Input.is_action_pressed("run") else speed
	
	current_friction += friction_modifier
	current_friction = clamp(current_friction, 0.1, 0.99)
	
	current_speed += speed_modifier
	current_speed = clamp(current_speed, 10, INF)
	
	current_jump_power = jump_power
	current_jump_power += jump_power_modifier
	current_jump_power = clamp(current_jump_power, 0, INF)
	
	current_gravity = gravity
	current_gravity += gravity_modifier
	current_gravity = clamp(current_gravity, 0, INF)
	
	velocity.x += current_speed * (int(Input.is_action_pressed("right")) - int(Input.is_action_pressed("left")))
	velocity.x *= current_friction
	
	if (on_floor || (on_ceiling && stuck_to_ceiling) || side_friction == 0.5) && Input.is_action_pressed("jump"):
		velocity.y -= current_jump_power
	else:
		velocity.y += current_gravity * delta
	velocity.y *= side_friction
	
	var last_v = velocity
	move_and_slide()
	
	if velocity.x != 0: $hitbox/sprite.flip_h = velocity.x > 0
	
	on_floor = false
	on_ceiling = false
	stuck_to_ceiling = false
	friction_modifier = 0
	speed_modifier = 0
	jump_power_modifier = 0
	gravity_modifier = 0
	side_friction = 1
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		var normal = collision.get_normal()
		var hori = false
		
		if collision:
			if normal.dot(Vector2.UP) > 0:
				on_floor = true
			elif normal.dot(Vector2.DOWN) > 0:
				on_ceiling = true
			else:
				hori = true
		
		if collider is TileMapLayer:
			var tile = get_tile_type(collider, collision.get_position() - normal * 2)
			match tile:
				"bouncy":
					var bounce = 0.1 if Input.is_action_pressed("down") else 0.5
					if hori:
						velocity.x = -last_v.x * bounce
					else:
						if abs(last_v.y) > 100: velocity.y = -last_v.y * bounce
				"extrabouncy":
					var bounce = 0.1 if Input.is_action_pressed("down") else 0.65
					if hori:
						velocity.x = -last_v.x * bounce
					else:
						if abs(last_v.y) > 100: velocity.y = -last_v.y * bounce
				"ice":
					friction_modifier = 0.99
					speed_modifier = -1000
				"sticky":
					speed_modifier = -100
					jump_power_modifier = -700
					if !on_floor: 
						if on_ceiling:
							stuck_to_ceiling = true
						if hori:
							side_friction = 0.5
				"hurt":
					friction_modifier = -0.5
					if health > 0:
						health -= 0.3
	
	evaulateState()
