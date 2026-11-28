extends CharacterBody2D

@export var speed = 100
@export var sprint = 200
@export var air_speed = 10
@export var current_speed = speed

@export var jump_power = 700
@export var current_jump_power = jump_power
@export var jumpPower: float = 700.0

@export var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
@export var current_gravity = gravity

@export var side_friction = 1
@export var current_friction = friction

@export var friction: float = 0.8
@export var air_friction: float = 0.99
@export var air_res: float = 0.99
@export var bounce: float = 0.5

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

var friction_modifier: float = 0.0
var speed_modifier: float = 0.0
var jump_power_modifier: float = 0.0
var gravity_modifier: float = 0.0

@export_group("Landing (wide and strong)")
@export var land_press: float = 0.6
@export var land_ripple_scale: float = 600.0
@export var min_land_speed: float = 150.0
@export var land_cooldown: float = 0.5   
@export var max_bounce_speed: float = 1400.0   

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

@export_group("Ceiling stick")
@export var stick_time: float = 1.5        
@export var stick_cooldown: float = 0.8    
@export var stick_move_speed: float = 1.5 
@export var stuck_jiggle_scale: float = 0.2 
@export var jiggle_scale_ease: float = 6.0   
@export var stick_span: float = 24.0         
@export var debug_stick: bool = false        

@export_group("Jiggle edges")
@export_range(0.0, 1.0) var edge_lock: float = 1.0  

@export_group("Ground movement")
@export var plain_jump_mul: float = 1.   
@export var ground_speed_mul: float = 1.1  

@export_group("Death transition")
@export var close_time: float = 0.4    
@export var hold_time: float = 0.9      
@export var open_time: float = 0.55   
@export var transition_color: Color = Color(0.42, 0.02, 0.08)   
@export var slash_power: float = 4.0    
@export var death_text_size: int = 72
@export var death_font: Font            

var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")
var last_v: Vector2
var boingboing: bool = true
var falling: int = 0
var onfloor: bool = false
var ogbounce = bounce
var respawn_node

# ---------------------------------------------------------------------------
# DEATH: one per line in quotes, then a comma.
# ---------------------------------------------------------------------------
const DEATH_MESSAGES := [
	"not today",
	"maybe next time",
	"go call houston",
	"my grandma could to better",
	"that was a practice run",
	"just testing for bugs",
	"slimed out",
	"jell-no",
]


const SURFACES := {
	
	"ice":         {"friction": 0.985, "speed": 0.1, "bounce_mul": 0.0},
	"bouncy":      {"bounce_mul": 1.0},
	"extrabouncy": {"bounce_mul": 2.4},
	"hard":        {"bounce_mul": 0.0, "speed": 1.2},  
}
const HAZARDS := ["hurt"]


const JIGGLE_TILES := {
	"bouncy":      1.0,
	"extrabouncy": 1.0,
	"sticky":      0.35,
}


const SOUND_TYPES := ["ice", "bouncy", "extrabouncy", "sticky", "hard"]

var surf: Dictionary = {}   
var ground_tile: String = ""  
var last_floor_type: String = ""       
var last_floor_jiggly: bool = false    

var stuck: bool = false
var stick_left: float = 0.0
var stick_cd: float = 0.0
var land_cd: float = 0.0
var jiggle_scale: float = 1.0

var press: float = 0.0
var press_vel: float = 0.0
var ripple: float = 0.0
var radius_scale: float = 1.0
var ground_timer: float = 0.0
var was_grounded: bool = true
var dent_pos: Vector2
var dent_pos_ready: bool = false
var jiggle_mat: ShaderMaterial
var jiggle_shader: Shader
var grid_tex: ImageTexture

var sound_bank: Dictionary = {}   
var jump_player: AudioStreamPlayer
var land_player: AudioStreamPlayer
var move_player: AudioStreamPlayer
var move_active: bool = false
var move_type: String = ""
var move_amount: float = 0.0
var move_idle_time: float = 0.0

var dying: bool = false
var last_death_message: String = ""
var transition_layer: CanvasLayer
var transition_rect: ColorRect
var transition_label: Label
var slash_mat: ShaderMaterial
var square_mat: ShaderMaterial

func get_tile_type(layer: TileMapLayer, world_pos: Vector2) -> String:
	if layer.tile_set == null or not layer.tile_set.has_custom_data_layer_by_name("type"):
		return ""
	var cell := layer.local_to_map(layer.to_local(world_pos))
	var data := layer.get_cell_tile_data(cell)
	if data == null:
		return ""
	var value = data.get_custom_data("type")
	return value if value is String else ""

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

// one pixel per tile: R = jiggle weight (0..1), G = 1 if a tile exists there
uniform sampler2D cell_data : filter_nearest;
uniform vec2 grid_origin = vec2(0.0);   // world position of the top-left corner of cell (0, 0)
uniform vec2 cell_size = vec2(100.0);   // world size of one tile
uniform ivec2 grid_min = ivec2(0);      // first cell stored in the texture
uniform ivec2 grid_size = ivec2(0);     // texture size in cells
uniform float edge_lock = 1.0;          // 1 = fully pinned where jiggly meets non-jiggly

// A tile corner is shared by up to 4 cells. If any of them is a non-jiggly tile,
// the corner is locked in place (edge_lock), so the jiggly tile stretches from there
// instead of pulling away and leaving a gap. Both tiles share the corner, so they
// always agree and nothing tears.
float corner_weight(vec2 world) {
	vec2 q = (world - grid_origin) / cell_size;
	ivec2 g = ivec2(round(q));
	float w = 1.0;
	bool touches_static = false;
	bool has_jiggly = false;
	for (int dy = -1; dy <= 0; dy++) {
		for (int dx = -1; dx <= 0; dx++) {
			ivec2 c = g + ivec2(dx, dy) - grid_min;
			if (c.x < 0 || c.y < 0 || c.x >= grid_size.x || c.y >= grid_size.y) {
				continue;
			}
			vec2 d = texelFetch(cell_data, c, 0).rg;
			if (d.g > 0.5) {
				if (d.r < 0.01) {
					touches_static = true;
				} else {
					has_jiggly = true;
					w = min(w, d.r);
				}
			}
		}
	}
	if (touches_static) {
		return has_jiggly ? w * (1.0 - edge_lock) : 0.0;
	}
	return w;
}

void vertex() {
	vec2 world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	float w = corner_weight(world);
	vec2 to_vert = world - player_pos;
	float dist = length(to_vert);
	vec2 dir = dist > 0.001 ? to_vert / dist : vec2(0.0, 1.0);

	// held dent
	float dent_fall = 1.0 - smoothstep(0.0, dent_radius, dist);
	dent_fall = pow(dent_fall, dent_softness);
	VERTEX.y += press * dent_fall * w;
	VERTEX.x -= to_vert.x / dent_radius * press * dent_fall * dent_pull * w;

	// ripple wave
	float wave_fall = 1.0 - smoothstep(0.0, wave_radius, dist);
	float wave = sin(TIME * frequency - dist * 0.15);
	VERTEX += dir * wave * wave_fall * strength * push * w;
	VERTEX.y += wave_fall * strength * push * 0.5 * w;
}
"""


const SLASH_SHADER := """
shader_type canvas_item;
render_mode unshaded;

uniform float t = 0.5; // value between 0 and 1 (animation start and end)
uniform float power = 10.0;
uniform vec4 mask_color : source_color = vec4(0.0, 0.0, 0.5, 1.0);
uniform vec4 background_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec2 normal = vec2(1.0, 1.0);
uniform float offset = -0.5;

void fragment() {
	vec2 p = UV;

	float dist = abs(dot(normalize(normal), p) + offset);

	float thickness = pow(t, power);

	float line = dist <= thickness ? 1.0 : 0.0;

	COLOR = mix(background_color, mask_color, line);
}
"""

const SQUARE_SHADER := """
shader_type canvas_item;
render_mode unshaded;

uniform float t = 0.5; // value between 0 and 1 (animation start and end)
uniform vec4 mask_color : source_color = vec4(0.0, 0.0, 0.5, 1.0);
uniform vec4 background_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec2 translate = vec2(-0.25, -0.25);
uniform float extra_size = 1.0;

// returns 1 if it's inside the square, otherwise returns 0
float square(vec2 uv, float width)
{
	return step(max(abs(uv.x), abs(uv.y)), width);
}

vec2 rotate(vec2 uv, float angle)
{
	return uv * mat2(vec2(sin(angle), -cos(angle)), vec2(cos(angle), sin(angle)));
}

void fragment() {
	// convert from 0..1 to -1..1
	vec2 uv = UV * 2.0 - 1.0;

	// fix aspect ratio
	uv.y *= SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y;

	// translate
	uv += translate;

	// rotate UVs
	uv = rotate(uv, PI * 0.25);

	// "draw" square
	float sqr = square(uv, (1.0 + extra_size) * t);
	COLOR = mix(mask_color, background_color, sqr);
}
"""

func _ready():
	$hurtbox.body_entered.connect(on_hit)
	respawn_node = get_node("../respawn")
	respawn()
	
	jiggle_shader = Shader.new()
	jiggle_shader.code = JIGGLE_SHADER
	jiggle_mat = ShaderMaterial.new()
	jiggle_mat.shader = jiggle_shader
	
	if water_tile_map == null:
		var root := get_tree().current_scene
		if root == null:
			root = get_tree().root
		water_tile_map = root.find_child(layer_node_name, true, false) as TileMapLayer
	
	if water_tile_map == null:
		push_error("JIGGLE: no TileMapLayer found. Assign one or fix layer_node_name.")
	else:
		_apply_material()
		call_deferred("_build_jiggle_grid")
	
	_setup_audio()


func _build_jiggle_grid() -> void:
	var layer := water_tile_map
	if layer == null or layer.tile_set == null:
		return
	var rect := layer.get_used_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var has_type := layer.tile_set.has_custom_data_layer_by_name("type")
	if not has_type:
		push_warning("JIGGLE: TileSet has no 'type' custom data layer, so every tile will jiggle.")
	
	var img := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RG8)
	for cell in layer.get_used_cells():
		var w: float = 1.0
		if has_type:
			var t := ""
			var data := layer.get_cell_tile_data(cell)
			if data != null:
				var v = data.get_custom_data("type")
				if v is String:
					t = v
			w = float(JIGGLE_TILES.get(t, 0.0))
		img.set_pixel(cell.x - rect.position.x, cell.y - rect.position.y, Color(w, 1.0, 0.0))
	grid_tex = ImageTexture.create_from_image(img)
	
	var tile_px := Vector2(layer.tile_set.tile_size)
	var origin := layer.to_global(layer.map_to_local(Vector2i.ZERO) - tile_px * 0.5)
	jiggle_mat.set_shader_parameter("cell_data", grid_tex)
	jiggle_mat.set_shader_parameter("grid_origin", origin)
	jiggle_mat.set_shader_parameter("cell_size", tile_px * layer.global_scale)
	jiggle_mat.set_shader_parameter("grid_min", rect.position)
	jiggle_mat.set_shader_parameter("grid_size", rect.size)

# ---------------------------------------------------------------------------
# AUDIO
# ---------------------------------------------------------------------------
func _setup_audio() -> void:
	sound_bank = {
		"jump": _load_sound_bank(jump_keyword),
		"land": _load_sound_bank(land_keyword),
		"move": _load_sound_bank(move_keyword),
	}
	
	jump_player = AudioStreamPlayer.new()
	land_player = AudioStreamPlayer.new()
	move_player = AudioStreamPlayer.new()
	add_child(jump_player)
	add_child(land_player)
	add_child(move_player)
	
	jump_player.volume_db = jump_volume_db
	land_player.volume_db = land_volume_db
	move_player.volume_db = -80.0
	
	move_player.finished.connect(_on_move_finished)

func _sound_type_of(file_lower: String) -> String:
	var best := "default"
	var best_len := 0
	for t in SOUND_TYPES:
		if file_lower.contains(t) and t.length() > best_len:
			best = t
			best_len = t.length()
	return best

func _load_sound_bank(keyword: String) -> Dictionary:
	var bank := {}
	var dir := DirAccess.open(audio_folder)
	if dir == null:
		push_warning("AUDIO: folder not found: " + audio_folder)
		return bank
	
	var seen := {}
	for file in dir.get_files():
		var f := file.trim_suffix(".import").trim_suffix(".remap")
		var ext := f.get_extension().to_lower()
		if ext != "wav" and ext != "ogg" and ext != "mp3":
			continue
		var lower := f.to_lower()
		if not lower.contains(keyword.to_lower()):
			continue
		if seen.has(f):
			continue
		seen[f] = true
		var res: Resource = load(audio_folder.path_join(f))
		if res is AudioStream:
			var s: AudioStream = res as AudioStream
			if keyword == move_keyword:
				s = _make_loop(s)
			var key := _sound_type_of(lower)
			if not bank.has(key):
				bank[key] = []
			bank[key].append(s)
	
	if bank.is_empty():
		push_warning("AUDIO: no files containing '" + keyword + "' in " + audio_folder)
	return bank

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

func _sound_list(action: String, tile_type: String) -> Array:
	var bank: Dictionary = sound_bank.get(action, {})
	var list: Array = bank.get(tile_type, [])
	if list.is_empty():
		list = bank.get("default", [])
	return list

func play_sound(player: AudioStreamPlayer, action: String, tile_type: String, pitch_min: float, pitch_max: float) -> void:
	if player == null:
		return
	var list := _sound_list(action, tile_type)
	if list.is_empty():
		return
	player.stream = list.pick_random()
	player.pitch_scale = randf_range(pitch_min, pitch_max)
	player.play()

func _start_move_stream() -> void:
	move_type = last_floor_type
	var list := _sound_list("move", move_type)
	if list.is_empty():
		return
	move_player.stream = list.pick_random()
	move_player.play()

func _stop_move_sound() -> void:
	move_active = false
	move_amount = 0.0
	if move_player != null:
		move_player.stop()

func _on_move_finished() -> void:
	if move_active:
		_start_move_stream()

func _update_move_sound(delta: float, grounded: bool) -> void:
	if move_player == null:
		return
	
	var spd: float = abs(velocity.x)
	var wants_sound: bool = grounded and spd > move_min_speed and not _sound_list("move", last_floor_type).is_empty()
	
	if wants_sound:
		move_idle_time = 0.0
		if not move_active:
			move_active = true
			move_amount = 0.0
			_start_move_stream()
		elif move_type != last_floor_type:
			_start_move_stream()  
	else:
		move_idle_time += delta
		if move_active and move_idle_time > move_stop_delay:
			_stop_move_sound()
			return
	
	if move_active:
		var target: float = clamp(spd / move_full_speed, 0.0, 1.0) if wants_sound else 0.0
		move_amount = lerp(move_amount, target, 1.0 - exp(-move_volume_ease * delta))
		move_player.volume_db = linear_to_db(max(move_amount, 0.0001)) + move_max_volume_db

# ---------------------------------------------------------------------------
# JELLY
# ---------------------------------------------------------------------------
func _apply_material() -> void:
	if water_tile_map == null:
		return
	water_tile_map.use_parent_material = false
	if water_tile_map.material != jiggle_mat:
		water_tile_map.material = jiggle_mat

func add_ripple(amount: float) -> void:
	ripple = min(ripple + amount, max_ripple)

# ---------------------------------------------------------------------------
# DEATH
# ---------------------------------------------------------------------------
func _random_death_message() -> String:
	if DEATH_MESSAGES.is_empty():
		return ""
	var msg: String = DEATH_MESSAGES.pick_random()
	if DEATH_MESSAGES.size() > 1:
		while msg == last_death_message:
			msg = DEATH_MESSAGES.pick_random()
	last_death_message = msg
	return msg

func _ensure_transition() -> void:
	if transition_layer != null and is_instance_valid(transition_layer):
		return
	
	var slash_shader := Shader.new()
	slash_shader.code = SLASH_SHADER
	slash_mat = ShaderMaterial.new()
	slash_mat.shader = slash_shader
	slash_mat.set_shader_parameter("mask_color", transition_color)
	slash_mat.set_shader_parameter("power", slash_power)
	
	var square_shader := Shader.new()
	square_shader.code = SQUARE_SHADER
	square_mat = ShaderMaterial.new()
	square_mat.shader = square_shader
	square_mat.set_shader_parameter("mask_color", transition_color)
	
	transition_layer = CanvasLayer.new()
	transition_layer.layer = 100
	transition_layer.visible = false
	
	evaulateState()
