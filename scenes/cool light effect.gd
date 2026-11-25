@tool
extends Polygon2D

@export var fadeWidth: float = 100.0
@export_range(0.5, 4.0) var fadePower: float = 1.0
@export_range(32, 512) var resolution: int = 128
@export_range(0, 8) var edgeBlur: int = 3
@export var shadowCaster: Sprite2D
@export_range(0.0, 1.0) var shadowStrength: float = 0.85
@export var shadowSoftness: float = 8.0
@export var shadowSpread: float = 0.15
@export_range(16, 128) var shadowDetail: int = 40
@export_range(0, 8) var shadowBlur: int = 3
@export var beamOrigin: Vector2 = Vector2.ZERO

var lastKey: String = ""
var pending: bool = false
var shadowKey: String = ""
var shadowSourceTexture: Texture2D
var shadowSourceImage: Image
var shadowTexture: ImageTexture
var shadowRect: Rect2 = Rect2()
var shadowTexelsPerLocal: float = 1.0

func _ready():
	texture_filter = TEXTURE_FILTER_LINEAR
	bake()

func _process(_delta):
	if makeKey() != lastKey and not pending:
		pending = true
		await get_tree().create_timer(0.25).timeout
		pending = false
		bake()
	updateShadow()

func makeKey() -> String:
	return str(hash(polygon), "|", fadeWidth, "|", fadePower, "|", resolution, "|", edgeBlur)

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

func bakeShadow() -> void:
	var sprite := shadowCaster
	var tex := sprite.texture
	var key := str(tex.get_instance_id(), "|", sprite.frame, "|", sprite.hframes, "|", sprite.vframes, "|", sprite.region_enabled, "|", sprite.region_rect, "|", shadowDetail, "|", shadowBlur)
	if key == shadowKey:
		return
	shadowKey = key

	if shadowSourceTexture != tex:
		shadowSourceTexture = tex
		shadowSourceImage = tex.get_image()
		if shadowSourceImage != null and shadowSourceImage.is_compressed():
			shadowSourceImage.decompress()
	if shadowSourceImage == null:
		shadowTexture = null
		return

	var texSize := tex.get_size()
	var region := Rect2(Vector2.ZERO, texSize)
	if sprite.region_enabled:
		region = sprite.region_rect
	elif sprite.hframes > 1 or sprite.vframes > 1:
		var frameSize := texSize / Vector2(sprite.hframes, sprite.vframes)
		region = Rect2(Vector2(sprite.frame_coords) * frameSize, frameSize)

	var crop := shadowSourceImage.get_region(Rect2i(region))
	crop.convert(Image.FORMAT_RGBA8)
	var longest := maxf(region.size.x, region.size.y)
	var w := maxi(int(round(region.size.x / longest * shadowDetail)), 2)
	var h := maxi(int(round(region.size.y / longest * shadowDetail)), 2)
	crop.resize(w, h, Image.INTERPOLATE_LANCZOS)

	var pad := shadowBlur * 3 + 4
	var cw := w + pad * 2
	var ch := h + pad * 2
	var vals := PackedFloat32Array()
	vals.resize(cw * ch)
	for y in h:
		for x in w:
			vals[(y + pad) * cw + (x + pad)] = crop.get_pixel(x, y).a
	if shadowBlur > 0:
		vals = boxBlur(boxBlur(vals, cw, ch, shadowBlur), cw, ch, shadowBlur)

	var canvas := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
	for y in ch:
		for x in cw:
			canvas.set_pixel(x, y, Color(1.0, 1.0, 1.0, vals[y * cw + x]))
	canvas.generate_mipmaps()

	var rect := sprite.get_rect()
	var scaleX := w / rect.size.x
	var scaleY := h / rect.size.y
	shadowRect = Rect2(rect.position - Vector2(pad / scaleX, pad / scaleY), Vector2(cw / scaleX, ch / scaleY))
	shadowTexelsPerLocal = (scaleX + scaleY) * 0.5
	shadowTexture = ImageTexture.create_from_image(canvas)

func updateShadow():
	var mat := material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("beamOrigin", beamOrigin)
	mat.set_shader_parameter("beamOriginWorld", to_global(beamOrigin))
	if shadowCaster == null or shadowCaster.texture == null:
		mat.set_shader_parameter("shadowStrength", 0.0)
		return
	bakeShadow()
	if shadowTexture == null:
		mat.set_shader_parameter("shadowStrength", 0.0)
		return

	var gt := shadowCaster.get_global_transform()
	var inv := gt.affine_inverse()
	var worldPerLocal := maxf(gt.basis_xform(Vector2(1.0, 0.0)).length(), 0.0001)
	var hx := gt.basis_xform(Vector2(shadowRect.size.x * 0.5, 0.0)).length()
	var hy := gt.basis_xform(Vector2(0.0, shadowRect.size.y * 0.5)).length()

	mat.set_shader_parameter("shadowTex", shadowTexture)
	mat.set_shader_parameter("shadowStrength", shadowStrength)
	mat.set_shader_parameter("shadowSoftness", shadowSoftness)
	mat.set_shader_parameter("shadowSpread", shadowSpread)
	mat.set_shader_parameter("invX", Vector2(inv.x.x, inv.y.x))
	mat.set_shader_parameter("invY", Vector2(inv.x.y, inv.y.y))
	mat.set_shader_parameter("invOrigin", inv.origin)
	mat.set_shader_parameter("rectPos", shadowRect.position)
	mat.set_shader_parameter("rectSize", shadowRect.size)
	mat.set_shader_parameter("flipH", shadowCaster.flip_h)
	mat.set_shader_parameter("flipV", shadowCaster.flip_v)
	mat.set_shader_parameter("casterCenter", shadowCaster.to_global(shadowRect.get_center()))
	mat.set_shader_parameter("casterRadius", sqrt(hx * hx + hy * hy))
	mat.set_shader_parameter("texelsPerWorld", shadowTexelsPerLocal / worldPerLocal)
