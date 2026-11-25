@tool
extends Polygon2D

@export var fadeWidth: float = 200.0
@export_range(0.5, 4.0) var fadePower: float = 1.0
@export_range(32, 512) var resolution: int = 128
@export_range(0, 8) var edgeBlur: int = 3
@export var lightPolygon: Polygon2D
@export var target: Node2D
@export_range(0.0, 1.0) var darknessInLight: float = 0.85
@export var lightFeather: float = 150.0
@export var adjustSpeed: float = 2.5

var lastKey: String = ""
var pending: bool = false
var lightAmount: float = 0.0

func _ready():
	texture_filter = TEXTURE_FILTER_LINEAR
	if target == null and not Engine.is_editor_hint():
		target = get_tree().current_scene.find_child("player", true, false) as Node2D
	bake()

func _process(delta):
	if makeKey() != lastKey and not pending:
		pending = true
		await get_tree().create_timer(0.25).timeout
		pending = false
		bake()
	updateLight(delta)

func makeKey() -> String:
	return str(hash(polygon), "|", fadeWidth, "|", fadePower, "|", resolution, "|", edgeBlur)

func lightDepth() -> float:
	var pts := lightPolygon.polygon
	var n := pts.size()
	if n < 3:
		return 0.0
	var p := lightPolygon.to_local(target.global_position) - lightPolygon.offset
	var d := INF
	for i in n:
		var c := Geometry2D.get_closest_point_to_segment(p, pts[i], pts[(i + 1) % n])
		d = minf(d, p.distance_to(c))
	var signedDist := d if Geometry2D.is_point_in_polygon(p, pts) else -d
	return smoothstep(0.0, maxf(lightFeather, 0.001), signedDist)

func updateLight(delta: float) -> void:
	var goal := 0.0
	if lightPolygon != null and target != null and not Engine.is_editor_hint():
		goal = lightDepth()
	lightAmount = lerpf(lightAmount, goal, 1.0 - exp(-adjustSpeed * delta))
	var eased := lightAmount * lightAmount * (3.0 - 2.0 * lightAmount)
	var mat := material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("darkColor", Color(color.r, color.g, color.b, 1.0))
	mat.set_shader_parameter("darkness", lerpf(color.a, darknessInLight, eased))

func boxBlur(src: PackedFloat32Array, w: int, h: int, r: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(w * h)
	for y in h:
		for x in w:
			var sum := 0.0
			for k in range(-r, r + 1):
				sum += src[y * w + clampi(x + k, 0, w - 1)]
			tmp[y * w + x] = sum / float(2 * r + 1)
	var out := PackedFloat32Array()
	out.resize(w * h)
	for y in h:
		for x in w:
			var sum := 0.0
			for k in range(-r, r + 1):
				sum += tmp[clampi(y + k, 0, h - 1) * w + x]
			out[y * w + x] = sum / float(2 * r + 1)
	return out

func bake():
	lastKey = makeKey()
	var n := polygon.size()
	if n < 3:
		return

	var minP: Vector2 = polygon[0]
	var maxP: Vector2 = polygon[0]
	for p in polygon:
		minP = Vector2(minf(minP.x, p.x), minf(minP.y, p.y))
		maxP = Vector2(maxf(maxP.x, p.x), maxf(maxP.y, p.y))
	var size := maxP - minP
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var longest := maxf(size.x, size.y)
	var w := maxi(int(ceil(size.x / longest * resolution)), 2)
	var h := maxi(int(ceil(size.y / longest * resolution)), 2)
	var sc := Vector2(w / size.x, h / size.y)

	var vals := PackedFloat32Array()
	vals.resize(w * h)
	for y in h:
		for x in w:
			var p := minP + Vector2(x + 0.5, y + 0.5) / sc
			var v := 0.0
			if Geometry2D.is_point_in_polygon(p, polygon):
				var d := INF
				for i in n:
					var c := Geometry2D.get_closest_point_to_segment(p, polygon[i], polygon[(i + 1) % n])
					d = minf(d, p.distance_to(c))
				var t := clampf(d / fadeWidth, 0.0, 1.0)
				v = pow(t * t * t * (t * (t * 6.0 - 15.0) + 10.0), fadePower)
			vals[y * w + x] = v

	if edgeBlur > 0:
		vals = boxBlur(boxBlur(vals, w, h, edgeBlur), w, h, edgeBlur)

	var img := Image.create(w, h, false, Image.FORMAT_L8)
	for y in h:
		for x in w:
			var v := vals[y * w + x]
			img.set_pixel(x, y, Color(v, v, v, 1.0))

	var uvs := PackedVector2Array()
	for p in polygon:
		uvs.append((p - minP) * sc)
	uv = uvs
	texture = ImageTexture.create_from_image(img)
