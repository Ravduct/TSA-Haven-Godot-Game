extends CharacterBody2D

@export var speed: float = 100.0
@export var jumpPower: float = 500.0
@export var friction: float = 0.8
@export var air_res: float = 0.99
@export var bounce: float = 0.4

@export var water_tile_map: TileMapLayer
@export var layer_node_name: String = "TileMapLayer"
@export var feet_offset: Vector2 = Vector2(0, 8)
@export var debug_always_jiggle: bool = false

@export_group("Held dent")
@export var press_depth: float = 8.0
@export var dent_radius: float = 600.0
@export var dent_softness: float = 0.4
@export var dent_pull: float = 0.15
@export var press_stiffness: float = 60.0
@export var press_damping: float = 6.0
@export var max_press: float = 60.0
@export var follow_speed: float = 8.0
@export var ground_grace: float = 0.12

@export_group("Jump (small and light)")
@export var jump_radius_scale: float = 0.3
@export var jump_squash_depth: float = 14.0
@export var jump_ripple: float = 0.15
@export var radius_ease: float = 4.0

@export_group("Landing (wide and strong)")
@export var land_press: float = 0.6
@export var land_ripple_scale: float = 600.0
@export var min_land_speed: float = 150.0

@export_group("Ripple wave")
@export var ripple_duration: float = 1.5
@export var max_ripple: float = 1.5
@export var run_ripple: float = 0.15
@export var wave_radius: float = 500.0
@export var wave_frequency: float = 90.0
@export var wave_push: float = 25.0

@export_group("Audio")
@export var audio_folder: String = "res://audio"
@export var jump_keyword: String = "jump"
@export var land_keyword: String = "land"
@export var move_keyword: String = "mov"
@export var jump_pitch_min: float = 0.85
@export var jump_pitch_max: float = 1.15
@export var land_pitch_min: float = 0.8
@export var land_pitch_max: float = 1.1
@export var jump_volume_db: float = 0.0
@export var land_volume_db: float = 0.0
@export var move_max_volume_db: float = 0.0
@export var move_full_speed: float = 400.0
@export var move_min_speed: float = 20.0
@export var move_volume_ease: float = 12.0
@export var move_stop_delay: float = 0.25

var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")
var last_v: Vector2
var boingboing: bool = true
var falling: int = 0
var onfloor: bool = false
var ogbounce = bounce

var press: float = 0.0
var press_vel: float = 0.0
var ripple: float = 0.0
var radius_scale: float = 1.0
var ground_timer: float = 0.0
var was_grounded: bool = true
var dent_pos: Vector2
var dent_pos_ready: bool = false
var jiggle_mat: ShaderMaterial

var jump_sounds: Array[AudioStream] = []
var land_sounds: Array[AudioStream] = []
var move_sounds: Array[AudioStream] = []
var jump_player: AudioStreamPlayer
var land_player: AudioStreamPlayer
var move_player: AudioStreamPlayer
var move_active: bool = false
var move_amount: float = 0.0
var move_idle_time: float = 0.0

const JIGGLE_SHADER := """
shader_type canvas_item;

uniform vec2 player_pos = vec2(0.0);
uniform float dent_radius = 300.0;
uniform float dent_softness = 0.9;
uniform float dent_pull = 0.15;
uniform float wave_radius = 500.0;
uniform float press = 0.0;
uniform float strength = 0.0;
uniform float frequency = 25.0;
uniform float push = 25.0;

void vertex() {
	vec2 world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	vec2 to_vert = world - player_pos;
	float dist = length(to_vert);
	vec2 dir = dist > 0.001 ? to_vert / dist : vec2(0.0, 1.0);

	// held dent
	float dent_fall = 1.0 - smoothstep(0.0, dent_radius, dist);
	dent_fall = pow(dent_fall, dent_softness);
	VERTEX.y += press * dent_fall;
	VERTEX.x -= to_vert.x / dent_radius * press * dent_fall * dent_pull;

	// ripple wave
	float wave_fall = 1.0 - smoothstep(0.0, wave_radius, dist);
	float wave = sin(TIME * frequency - dist * 0.15);
	VERTEX += dir * wave * wave_fall * strength * push;
	VERTEX.y += wave_fall * strength * push * 0.5;
}
"""

func _ready():
	$hurtbox.body_entered.connect(on_hit)
	respawn()
	
	var shader := Shader.new()
	shader.code = JIGGLE_SHADER
	jiggle_mat = ShaderMaterial.new()
	jiggle_mat.shader = shader
	
	if water_tile_map == null:
		var root := get_tree().current_scene
		if root == null:
			root = get_tree().root
		water_tile_map = root.find_child(layer_node_name, true, false) as TileMapLayer
	
	if water_tile_map == null:
		push_error("JIGGLE: no TileMapLayer found. Assign one or fix layer_node_name.")
	else:
		_apply_material()
	
	_setup_audio()

func _setup_audio() -> void:
	jump_sounds = _load_sounds(jump_keyword)
	land_sounds = _load_sounds(land_keyword)
	move_sounds = _load_sounds(move_keyword)
	
	jump_player = AudioStreamPlayer.new()
	land_player = AudioStreamPlayer.new()
	move_player = AudioStreamPlayer.new()
	add_child(jump_player)
	add_child(land_player)
	add_child(move_player)
	
	jump_player.volume_db = jump_volume_db
	land_player.volume_db = land_volume_db
	move_player.volume_db = -80.0
	
	# fallback: if a moving sound isn't set to loop and ends, start another
	move_player.finished.connect(_on_move_finished)

func _load_sounds(keyword: String) -> Array[AudioStream]:
	var result: Array[AudioStream] = []
	var dir := DirAccess.open(audio_folder)
	if dir == null:
		push_warning("AUDIO: folder not found: " + audio_folder)
		return result
	
	for file in dir.get_files():
		# exported games list files as name.ext.import / name.ext.remap
		var f := file.trim_suffix(".import").trim_suffix(".remap")
		var ext := f.get_extension().to_lower()
		if ext != "wav" and ext != "ogg" and ext != "mp3":
			continue
		if not f.to_lower().contains(keyword.to_lower()):
			continue
		var res: Resource = load(audio_folder.path_join(f))
		if res is AudioStream:
			var s: AudioStream = res as AudioStream
			if keyword == move_keyword:
				s = _make_loop(s)
			if not result.has(s):
				result.append(s)
	
	if result.is_empty():
		push_warning("AUDIO: no files containing '" + keyword + "' in " + audio_folder)
	return result

func _make_loop(s: AudioStream) -> AudioStream:
	var c: AudioStream = s.duplicate() as AudioStream
	if c is AudioStreamOggVorbis:
		(c as AudioStreamOggVorbis).loop = true
	elif c is AudioStreamMP3:
		(c as AudioStreamMP3).loop = true
	elif c is AudioStreamWAV:
		var w: AudioStreamWAV = c as AudioStreamWAV
		if w.format == AudioStreamWAV.FORMAT_8_BITS or w.format == AudioStreamWAV.FORMAT_16_BITS:
			var bytes: int = 2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1
			var channels: int = 2 if w.stereo else 1
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = w.data.size() / (bytes * channels)
	return c

func play_random(player: AudioStreamPlayer, sounds: Array[AudioStream], pitch_min: float, pitch_max: float) -> void:
	if player == null or sounds.is_empty():
		return
	player.stream = sounds.pick_random()
	player.pitch_scale = randf_range(pitch_min, pitch_max)
	player.play()

func _on_move_finished() -> void:
	if move_active and not move_sounds.is_empty():
		move_player.stream = move_sounds.pick_random()
		move_player.play()

func _update_move_sound(delta: float, grounded: bool) -> void:
	if move_player == null or move_sounds.is_empty():
		return
	
	var spd: float = abs(velocity.x)
	var wants_sound: bool = grounded and spd > move_min_speed
	
	if wants_sound:
		move_idle_time = 0.0
		if not move_active:
			move_active = true
			move_amount = 0.0
			move_player.stream = move_sounds.pick_random()
			move_player.play()
	else:
		move_idle_time += delta
		if move_active and move_idle_time > move_stop_delay:
			move_active = false
			move_amount = 0.0
			move_player.stop()
			return
	
	if move_active:
		# volume follows speed, and fades down while waiting to stop
		var target: float = clamp(spd / move_full_speed, 0.0, 1.0) if wants_sound else 0.0
		move_amount = lerp(move_amount, target, 1.0 - exp(-move_volume_ease * delta))
		move_player.volume_db = linear_to_db(max(move_amount, 0.0001)) + move_max_volume_db

func _apply_material() -> void:
	if water_tile_map == null:
		return
	water_tile_map.use_parent_material = false
	if water_tile_map.material != jiggle_mat:
		water_tile_map.material = jiggle_mat

func add_ripple(amount: float) -> void:
	ripple = min(ripple + amount, max_ripple)

func respawn() -> void:
	position = get_node("/root/Node2D/respawn").global_position
	velocity = Vector2.ZERO
	dent_pos_ready = false

func on_hit(body: Node):
	if body.name != "slime" || (body.get_meta_list().has("type") && body.get_meta("type") != "red"): return
	respawn()
	
func _process(_delta):
	bounce = 0.1 if Input.is_action_pressed("down") else ogbounce
	speed = 150 if Input.is_action_pressed("run") else 100

func _physics_process(delta: float):
	var direction := int(Input.is_action_pressed("right")) - int(Input.is_action_pressed("left"))
	var jumped := false
	
	if !onfloor:
		velocity.y += gravity * delta
		velocity.x *= air_res
		if direction:
			velocity.x += direction * (speed / 10)
	else:
		if Input.is_action_pressed("jump"):
			velocity.y -= jumpPower
			jumped = true
		if direction:
			velocity.x += direction * speed
		velocity.x *= friction
	
	last_v = velocity
	
	move_and_slide()
	
	onfloor = false
	falling += 1
	for i in get_slide_collision_count():
		var collide = get_slide_collision(i)
		if collide:
			var normal = collide.get_normal()
			var body = collide.get_collider()
			if body.name == "slime" && body.get_meta("type") == "purple":
				body.apply_central_impulse(normal * -velocity.length()/10)
			if boingboing:
				var mul = (1 if body.name == "slime" && body.get_meta("type") == "red" else 1.7)
				if normal.dot(Vector2.UP):
					velocity.y = last_v.y * -bounce * mul
					onfloor = true
					falling = 0
				elif normal.dot(Vector2.DOWN):
					velocity.y = last_v.y * -bounce * mul
				else:
					velocity.x = last_v.x * -bounce * mul
	if abs(velocity.y) < 0.1 && falling < 1:
		onfloor = true
	
	if position.y > 1500:
		respawn()
	
	if onfloor:
		ground_timer = ground_grace
	else:
		ground_timer = max(ground_timer - delta, 0.0)
	
	# jump: small, light squash in a small area
	if jumped and was_grounded:
		press = jump_squash_depth
		press_vel = 0.0
		radius_scale = jump_radius_scale
		add_ripple(jump_ripple)
		ground_timer = 0.0
		play_random(jump_player, jump_sounds, jump_pitch_min, jump_pitch_max)
	
	var grounded := ground_timer > 0.0
	
	# landing: full radius, strong hit
	if grounded and not was_grounded and abs(last_v.y) > min_land_speed:
		dent_pos = global_position + feet_offset
		radius_scale = 1.0
		press_vel += abs(last_v.y) * land_press
		add_ripple(clamp(abs(last_v.y) / land_ripple_scale, 0.3, max_ripple))
		play_random(land_player, land_sounds, land_pitch_min, land_pitch_max)
	elif onfloor and abs(velocity.x) > 20.0:
		add_ripple(min(abs(velocity.x) / speed, 1.0) * run_ripple * delta)
	
	was_grounded = grounded
	
	_update_jelly(delta, grounded)
	_update_move_sound(delta, grounded)

func _update_jelly(delta: float, grounded: bool) -> void:
	# ripples fade out over ripple_duration seconds
	if debug_always_jiggle:
		ripple = abs(sin(Time.get_ticks_msec() / 200.0))
	else:
		ripple *= exp(-3.0 * delta / max(ripple_duration, 0.01))
		if ripple < 0.005:
			ripple = 0.0
	
	# radius: small in the air, full on the ground
	var target_scale := 1.0 if grounded else jump_radius_scale
	radius_scale = lerp(radius_scale, target_scale, 1.0 - exp(-radius_ease * delta))
	
	# held dent spring
	var target := press_depth if grounded else 0.0
	press_vel += ((target - press) * press_stiffness - press_vel * press_damping) * delta
	press += press_vel * delta
	press = clamp(press, -max_press, max_press)
	if abs(target - press) < 0.05 and abs(press_vel) < 0.5:
		press = target
		press_vel = 0.0
	
	if water_tile_map == null:
		return
	
	# dent trails behind you on the ground, and stays at the launch spot in the air
	var feet := global_position + feet_offset
	if not dent_pos_ready:
		dent_pos = feet
		dent_pos_ready = true
	if grounded:
		dent_pos = dent_pos.lerp(feet, 1.0 - exp(-follow_speed * delta))
	
	_apply_material()
	jiggle_mat.set_shader_parameter("player_pos", dent_pos)
	jiggle_mat.set_shader_parameter("dent_radius", dent_radius * radius_scale)
	jiggle_mat.set_shader_parameter("dent_softness", dent_softness)
	jiggle_mat.set_shader_parameter("dent_pull", dent_pull)
	jiggle_mat.set_shader_parameter("wave_radius", wave_radius * radius_scale)
	jiggle_mat.set_shader_parameter("press", press)
	jiggle_mat.set_shader_parameter("strength", ripple)
	jiggle_mat.set_shader_parameter("frequency", wave_frequency)
	jiggle_mat.set_shader_parameter("push", wave_push)
