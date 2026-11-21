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

@export var health = 100

@export var state = PlayerState.IDLE
@export var on_floor = false
@export var on_ceiling = false
@export var stuck_to_ceiling = false

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
	
<<<<<<< Updated upstream
	transition_rect = ColorRect.new()
	transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_layer.add_child(transition_rect)
	
	transition_label = Label.new()
	transition_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	transition_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	transition_label.add_theme_font_size_override("font_size", death_text_size)
	transition_label.add_theme_color_override("font_color", Color.WHITE)
	transition_label.add_theme_color_override("font_outline_color", Color.BLACK)
	transition_label.add_theme_constant_override("outline_size", 16)
	if death_font != null:
		transition_label.add_theme_font_override("font", death_font)
	transition_label.rotation_degrees = -4.0
	transition_label.resized.connect(func(): transition_label.pivot_offset = transition_label.size * 0.5)
	transition_label.visible = false
	transition_layer.add_child(transition_label)
	
	var host: Node = get_tree().current_scene
	if host == null:
		host = get_tree().root
	host.add_child(transition_layer)

func _run_transition(mat: ShaderMaterial, from_t: float, to_t: float, time: float) -> void:
	transition_rect.material = mat
	mat.set_shader_parameter("t", from_t)
	var tw := create_tween()
	tw.tween_method(func(v: float): mat.set_shader_parameter("t", v), from_t, to_t, time)
	await tw.finished

func _pop_death_label(text: String) -> void:
	transition_label.text = text
	transition_label.visible = true
	transition_label.modulate.a = 0.0
	transition_label.scale = Vector2(1.5, 1.5)
	transition_label.rotation_degrees = -4.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(transition_label, "modulate:a", 1.0, 0.12)
	tw.tween_property(transition_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hide_death_label() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(transition_label, "modulate:a", 0.0, 0.3)
	tw.tween_property(transition_label, "scale", Vector2(1.4, 1.4), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(transition_label, "rotation_degrees", -9.0, 0.3)

func die() -> void:
	if dying:
		return
	dying = true
	velocity = Vector2.ZERO
	_stop_move_sound()
	_ensure_transition()
	transition_label.visible = false
	transition_layer.visible = true
	
	await _run_transition(slash_mat, 0.0, 1.0, close_time)
	
	respawn()
	_pop_death_label(_random_death_message())
	await get_tree().create_timer(hold_time).timeout
	
	_hide_death_label()
	await _run_transition(square_mat, 0.0, 1.0, open_time)
	transition_label.visible = false
	transition_layer.visible = false
	dying = false

func respawn() -> void:
	stuck = false
	position = respawn_node.global_position
	velocity = Vector2.ZERO
	dent_pos_ready = false
	var cam := get_node_or_null("camera") as Camera2D
	if cam != null:
		cam.reset_smoothing()

func on_hit(body: Node):
	if body.name != "slime" || (body.get_meta_list().has("type") && body.get_meta("type") != "red"): return
	die()
	
func _process(_delta):
	bounce = 0.1 if Input.is_action_pressed("down") else ogbounce
	speed = 150 if Input.is_action_pressed("run") else 100

func _tile_is_solid(layer: TileMapLayer, world_pos: Vector2) -> bool:
	var cell := layer.local_to_map(layer.to_local(world_pos))
	var data := layer.get_cell_tile_data(cell)
	if data == null:
		return false
	var ts := layer.tile_set
	if ts == null or ts.get_physics_layers_count() == 0:
		return true
	for i in ts.get_physics_layers_count():
		if data.get_collision_polygons_count(i) > 0:
			return true
	return false

func _is_sticky_ceiling(layer: TileMapLayer, collide: KinematicCollision2D) -> bool:
	var p: Vector2 = collide.get_position() - collide.get_normal() * 3.0
	if get_tile_type(layer, p) != "sticky":
		return false
	for dx in [-stick_span, -stick_span * 0.5, stick_span * 0.5, stick_span]:
		var q: Vector2 = p + Vector2(dx, 0)
		if _tile_is_solid(layer, q) and get_tile_type(layer, q) != "sticky":
			return false
	return true

func _start_stick() -> void:
	stuck = true
	stick_left = stick_time
	velocity = Vector2.ZERO

func _release_stick() -> void:
	stuck = false
	stick_cd = stick_cooldown
	velocity.y = 100.0 

func _physics_process(delta: float):
	if dying:
		velocity = Vector2.ZERO
		return
	
	var direction := int(Input.is_action_pressed("right")) - int(Input.is_action_pressed("left"))
	var jumped := false
	stick_cd = max(stick_cd - delta, 0.0)
	land_cd = max(land_cd - delta, 0.0)
	
	if stuck:
		stick_left -= delta
		velocity.x = direction * speed * stick_move_speed
		velocity.y = -60.0   
		if stick_left <= 0.0 or Input.is_action_just_pressed("jump") or Input.is_action_pressed("down"):
			_release_stick()
	elif !onfloor:
		velocity.y += gravity * delta
		velocity.x *= air_res
		if direction:
			velocity.x += direction * (speed / 10)
	else:
		if Input.is_action_pressed("jump"):
			var jump_mul: float = 1.0 if JIGGLE_TILES.has(ground_tile) else plain_jump_mul
			velocity.y = min(velocity.y, -jumpPower * jump_mul)   
			jumped = true
		if direction:
			var default_speed_mul: float = ground_speed_mul if ground_tile == "" else 1.0
			velocity.x += direction * speed * float(surf.get("speed", default_speed_mul))
		velocity.x *= float(surf.get("friction", friction))
	
	last_v = velocity
	
	move_and_slide()
	
	onfloor = false
	falling += 1
	var new_surf := {}
	var new_ground := ""
	var got_floor := false
	var touching_sticky := false
	
#kyle, this part should only work if the block is sticky, but it doesnt work right now
	var ceiling_sticky := false
	var ceiling_plain := false
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c != null and c.get_normal().y > 0.5 and c.get_collider() is TileMapLayer:
			if _is_sticky_ceiling(c.get_collider() as TileMapLayer, c):
				ceiling_sticky = true
			else:
				ceiling_plain = true
	var can_stick: bool = ceiling_sticky and not ceiling_plain
	
	for i in get_slide_collision_count():
		var collide = get_slide_collision(i)
		if collide:
			var normal = collide.get_normal()
			var body = collide.get_collider()
			
			var tile := ""
			if body is TileMapLayer:
				tile = get_tile_type(body, collide.get_position() - normal * 2.0)
				if tile in HAZARDS:
					die()
					return
				if normal.y < -0.5:
					new_ground = tile
					got_floor = true
					if SURFACES.has(tile):
						new_surf = SURFACES[tile]
				if normal.y > 0.5 and can_stick:
					touching_sticky = true
					if not stuck and stick_cd <= 0.0:
						if debug_stick:
							var sc: Vector2i = body.local_to_map(body.to_local(collide.get_position() - normal * 3.0))
							print("STICK on tile type '", tile, "' cell ", sc, " atlas ", body.get_cell_atlas_coords(sc))
						_start_stick()
			
			if body.name == "slime" && body.get_meta("type") == "purple":
				body.apply_central_impulse(normal * -velocity.length()/10)
			if boingboing and not stuck:
				var mul = (1 if body.name == "slime" && body.get_meta("type") == "red" else 1.7)
				mul *= SURFACES.get(tile, {}).get("bounce_mul", 1.0)
				if normal.dot(Vector2.UP):
					velocity.y = clamp(last_v.y * -bounce * mul, -max_bounce_speed, max_bounce_speed)
					onfloor = true
					falling = 0
				elif normal.dot(Vector2.DOWN):
					velocity.y = last_v.y * -bounce * mul
				else:
					velocity.x = last_v.x * -bounce * mul
					$boing.play()
	if stuck and not touching_sticky:
		_release_stick()   
	surf = new_surf
	ground_tile = new_ground
	if got_floor:
		last_floor_type = new_ground
		last_floor_jiggly = JIGGLE_TILES.has(new_ground)
	
	if abs(velocity.y) < 0.1 && falling < 1:
		onfloor = true
	
	if position.y > 1500:
		die()
		return
	
	if onfloor:
		ground_timer = ground_grace
	else:
		ground_timer = max(ground_timer - delta, 0.0)
	if jumped and was_grounded:
		ground_timer = 0.0
		play_sound(jump_player, "jump", last_floor_type, jump_pitch_min, jump_pitch_max)
		if last_floor_jiggly:
			press = jump_squash_depth
			press_vel = 0.0
			radius_scale = jump_radius_scale
			add_ripple(jump_ripple)
	
	var grounded := ground_timer > 0.0
	
	var landed: bool = grounded and not was_grounded and abs(last_v.y) > min_land_speed and not stuck
	if landed:
		play_sound(land_player, "land", last_floor_type, land_pitch_min, land_pitch_max)
		if last_floor_jiggly and land_cd <= 0.0:
			land_cd = land_cooldown
			dent_pos = global_position + feet_offset
			radius_scale = 1.0
			press_vel += abs(last_v.y) * land_press
			add_ripple(clamp(abs(last_v.y) / land_ripple_scale, 0.3, max_ripple))
	elif onfloor and abs(velocity.x) > 20.0 and last_floor_jiggly:
		add_ripple(min(abs(velocity.x) / speed, 1.0) * run_ripple * delta)
	
	was_grounded = grounded
	
	_update_jelly(delta, grounded)
	_update_move_sound(delta, grounded)

func _update_jelly(delta: float, grounded: bool) -> void:
	if debug_always_jiggle:
		ripple = abs(sin(Time.get_ticks_msec() / 200.0))
	else:
		ripple *= exp(-3.0 * delta / max(ripple_duration, 0.01))
		if ripple < 0.005:
			ripple = 0.0
	
	var target_scale := 1.0 if grounded else jump_radius_scale
	radius_scale = lerp(radius_scale, target_scale, 1.0 - exp(-radius_ease * delta))
	
	var target := press_depth if (grounded and last_floor_jiggly) else 0.0
	press_vel += ((target - press) * press_stiffness - press_vel * press_damping) * delta
	press += press_vel * delta
	press = clamp(press, -max_press, max_press)
	if abs(target - press) < 0.05 and abs(press_vel) < 0.5:
		press = target
		press_vel = 0.0
	
	if water_tile_map == null:
		return
	
	var feet := global_position + feet_offset
	if not dent_pos_ready:
		dent_pos = feet
		dent_pos_ready = true
	if grounded:
		dent_pos = dent_pos.lerp(feet, 1.0 - exp(-follow_speed * delta))
	
	var target_jiggle := stuck_jiggle_scale if stuck else 1.0
	jiggle_scale = lerp(jiggle_scale, target_jiggle, 1.0 - exp(-jiggle_scale_ease * delta))
	var radius_mul: float = max(jiggle_scale, 0.05)   
	
	_apply_material()
	jiggle_mat.set_shader_parameter("player_pos", dent_pos)
	jiggle_mat.set_shader_parameter("dent_radius", dent_radius * radius_scale * radius_mul)
	jiggle_mat.set_shader_parameter("dent_softness", dent_softness)
	jiggle_mat.set_shader_parameter("dent_pull", dent_pull * jiggle_scale)
	jiggle_mat.set_shader_parameter("wave_radius", wave_radius * radius_scale * radius_mul)
	jiggle_mat.set_shader_parameter("press", press * jiggle_scale)
	jiggle_mat.set_shader_parameter("strength", ripple * jiggle_scale)
	jiggle_mat.set_shader_parameter("frequency", wave_frequency)
	jiggle_mat.set_shader_parameter("edge_lock", edge_lock)
	jiggle_mat.set_shader_parameter("push", wave_push * jiggle_scale)
=======
	evaulateState()
>>>>>>> Stashed changes
