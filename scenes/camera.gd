extends Camera2D

@export var layers: Array[TileMapLayer] = []
@export var ignoreNames: Array[String] = ["enemy spawns"]
@export var padding: Vector2 = Vector2.ZERO
@export var normalZoom: float = 1.0
@export var bigSpaceZoom: float = 0.37
@export var zoomTime: float = 1.3
@export var easePower: float = 3.0
@export var edgeEase: float = 450.0
@export var zoneNames: Array[String] = ["Area2D"]
@export var target: Node2D

var zoneShapes: Array[CollisionShape2D] = []
var zoomFrom: float = 1.0
var zoomTo: float = 1.0
var zoomProgress: float = 1.0
var bounds: Rect2 = Rect2()
var hasBounds: bool = false

func _ready():
	if target == null:
		target = get_parent() as Node2D
	top_level = true
	limit_smoothed = false
	zoom = Vector2(normalZoom, normalZoom)
	zoomFrom = normalZoom
	zoomTo = normalZoom
	if target != null:
		global_position = target.global_position
	call_deferred("setup")

func setup() -> void:
	computeBounds()
	findZones(get_tree().current_scene)
	updatePosition()

func isZone(node: Node) -> bool:
	var n := String(node.name)
	return zoneNames.has(n) or n.to_lower().begins_with("zoom") or node.is_in_group("zoomZone")

func findZones(node: Node) -> void:
	if node is Area2D and isZone(node):
		for child in node.get_children():
			if child is CollisionShape2D and child.shape is RectangleShape2D:
				zoneShapes.append(child)
	for child in node.get_children():
		findZones(child)

func collectLayers(node: Node, out: Array[TileMapLayer]) -> void:
	if node is TileMapLayer and not ignoreNames.has(String(node.name)):
		out.append(node)
	for child in node.get_children():
		collectLayers(child, out)

func computeBounds() -> void:
	var found: Array[TileMapLayer] = []
	if layers.is_empty():
		collectLayers(get_tree().current_scene, found)
	else:
		found.assign(layers)

	var total := Rect2()
	var any := false
	for layer in found:
		var used := layer.get_used_rect()
		if used.size.x <= 0 or used.size.y <= 0 or layer.tile_set == null:
			continue
		var tileSize := Vector2(layer.tile_set.tile_size)
		var topLeft := layer.to_global(layer.map_to_local(used.position) - tileSize * 0.5)
		var bottomRight := layer.to_global(layer.map_to_local(used.end - Vector2i.ONE) + tileSize * 0.5)
		var r := Rect2(topLeft, bottomRight - topLeft).abs()
		total = r if not any else total.merge(r)
		any = true
	if not any:
		return

	bounds = total.grow_individual(padding.x, padding.y, padding.x, padding.y)
	hasBounds = true

func targetZoom() -> float:
	if target == null:
		return normalZoom
	for shapeNode in zoneShapes:
		if not is_instance_valid(shapeNode):
			continue
		var size: Vector2 = shapeNode.shape.size
		var local: Vector2 = shapeNode.to_local(target.global_position)
		if absf(local.x) <= size.x * 0.5 and absf(local.y) <= size.y * 0.5:
			return float(shapeNode.get_parent().get_meta("zoom", bigSpaceZoom))
	return normalZoom

func minAllowedZoom() -> float:
	if not hasBounds or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return 0.0
	var view := get_viewport_rect().size
	return maxf(view.x / bounds.size.x, view.y / bounds.size.y)

func easeInOut(t: float) -> float:
	if t < 0.5:
		return 0.5 * pow(2.0 * t, easePower)
	return 1.0 - 0.5 * pow(2.0 * (1.0 - t), easePower)

func softClamp(v: float, lo: float, hi: float, margin: float) -> float:
	if lo >= hi:
		return (lo + hi) * 0.5
	var m := minf(margin, (hi - lo) * 0.5)
	if m <= 0.001:
		return clampf(v, lo, hi)
	var upper := hi - m
	var lower := lo + m
	if v > upper:
		var t := clampf((v - upper) / (2.0 * m), 0.0, 1.0)
		return upper + m * (1.0 - (1.0 - t) * (1.0 - t))
	if v < lower:
		var t := clampf((lower - v) / (2.0 * m), 0.0, 1.0)
		return lower - m * (1.0 - (1.0 - t) * (1.0 - t))
	return v

func updatePosition() -> void:
	if target == null:
		return
	var center := target.global_position + offset
	if hasBounds:
		var half := get_viewport_rect().size / zoom * 0.5
		center.x = softClamp(center.x, bounds.position.x + half.x, bounds.end.x - half.x, edgeEase)
		center.y = softClamp(center.y, bounds.position.y + half.y, bounds.end.y - half.y, edgeEase)
	global_position = center - offset

func _process(delta):
	var z := maxf(targetZoom(), minAllowedZoom())
	if not is_equal_approx(z, zoomTo):
		zoomFrom = zoom.x
		zoomTo = z
		zoomProgress = 0.0
	if zoomProgress < 1.0:
		zoomProgress = minf(zoomProgress + delta / maxf(zoomTime, 0.01), 1.0)
		var value := lerpf(zoomFrom, zoomTo, easeInOut(zoomProgress))
		zoom = Vector2(value, value)
	updatePosition()
