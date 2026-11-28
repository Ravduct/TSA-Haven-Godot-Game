@tool
extends TileMapLayer

var pending: bool = false

func _ready():
	if not changed.is_connected(queueBuild):
		changed.connect(queueBuild)
	buildData()

func queueBuild() -> void:
	if pending:
		return
	pending = true
	call_deferred("buildDeferred")

func buildDeferred() -> void:
	pending = false
	buildData()

func buildData() -> void:
	var mat := material as ShaderMaterial
	if mat == null or tile_set == null:
		return
	var rect := get_used_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		return

	var w: int = rect.size.x
	var h: int = rect.size.y
	var occupied := PackedByteArray()
	occupied.resize(w * h)
	occupied.fill(0)
	for cell in get_used_cells():
		occupied[(cell.y - rect.position.y) * w + (cell.x - rect.position.x)] = 1

	var img := Image.create(w, h, false, Image.FORMAT_RG8)
	for x in w:
		var count := 0
		for y in h:
			if occupied[y * w + x] == 1:
				img.set_pixel(x, y, Color(minf(float(count), 254.0) / 255.0, 1.0, 0.0))
				count += 1
			else:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0))
				count = 0

	var tilePx := Vector2(tile_set.tile_size)
	var origin := to_global(map_to_local(rect.position) - tilePx * 0.5)
	mat.set_shader_parameter("cell_data", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("grid_origin", origin)
	mat.set_shader_parameter("cell_size", tilePx * global_scale)
	mat.set_shader_parameter("grid_size", rect.size)
