extends TileMapLayer

@export var target: Node2D
@export var frontZ: int = 10
@export var clearRadius: float = 300.0
@export var fadeRadius: float = 500.0
@export_range(0.0, 1.0) var minAlpha: float = 0.0
@export var sampleRadius: float = 90.0
@export_range(0.0, 1.0) var darkness: float = 0.35
@export var darkColor: Color = Color(0.0, 0.0, 0.05)
@export var easeSpeed: float = 3.0
@export var overlayLayer: int = 0

const FRONT_SHADER := """
shader_type canvas_item;

uniform vec2 playerPos = vec2(0.0);
uniform float clearRadius = 300.0;
uniform float fadeRadius = 500.0;
uniform float minAlpha = 0.0;
uniform float reveal = 0.0;

varying vec2 worldPos;

void vertex() {
	worldPos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float d = distance(worldPos, playerPos);
	float fade = smoothstep(clearRadius, clearRadius + fadeRadius, d);
	float seeThrough = mix(minAlpha, 1.0, fade);
	COLOR.a *= mix(1.0, seeThrough, reveal);
}
"""

var overlay: ColorRect
var frontMat: ShaderMaterial
var amount: float = 0.0

func _ready():
	z_index = frontZ
	if target == null:
		target = get_tree().current_scene.find_child("player", true, false) as Node2D

	var shader := Shader.new()
	shader.code = FRONT_SHADER
	frontMat = ShaderMaterial.new()
	frontMat.shader = shader
	use_parent_material = false
	material = frontMat

	buildOverlay()

func buildOverlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = overlayLayer
	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.color = Color(darkColor.r, darkColor.g, darkColor.b, 0.0)
	canvas.add_child(overlay)
	get_tree().current_scene.add_child.call_deferred(canvas)

func hasTile(worldPos: Vector2) -> bool:
	return get_cell_source_id(local_to_map(to_local(worldPos))) != -1

func coverage() -> float:
	var center := target.global_position
	var hits := 0
	if hasTile(center):
		hits += 1
	for i in 8:
		var angle := TAU * float(i) / 8.0
		if hasTile(center + Vector2(cos(angle), sin(angle)) * sampleRadius):
			hits += 1
	return float(hits) / 9.0

func _process(delta):
	if target == null:
		return
	amount = lerpf(amount, coverage(), 1.0 - exp(-easeSpeed * delta))
	var eased := amount * amount * (3.0 - 2.0 * amount)

	if overlay != null:
		overlay.color = Color(darkColor.r, darkColor.g, darkColor.b, darkness * eased)

	frontMat.set_shader_parameter("playerPos", target.global_position)
	frontMat.set_shader_parameter("clearRadius", clearRadius)
	frontMat.set_shader_parameter("fadeRadius", fadeRadius)
	frontMat.set_shader_parameter("minAlpha", minAlpha)
	frontMat.set_shader_parameter("reveal", eased)
