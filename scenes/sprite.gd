extends Sprite2D

@export var waterTileMap: TileMapLayer
@export var layerNodeName: String = "terrain"
@export var matchLayerNames: Array[String] = ["bg terrain"]
@export var feetOffset: Vector2 = Vector2(0, 8)
@export var footProbe: float = 6.0
@export var jumpAction: StringName = &"jump"
@export var debugAlwaysJiggle: bool = false
@export var groundGrace: float = 0.12
@export var minJumpSpeed: float = 150.0
@export var runRippleSpeed: float = 300.0

@export_group("Reach")
@export var reachHops: float = 6.0

@export_group("Held dent")
@export var pressDepth: float = 8.0
@export var dentRadius: float = 600.0
@export var dentSoftness: float = 0.4
@export var dentPull: float = 0.15
@export var pressStiffness: float = 60.0
@export var pressDamping: float = 6.0
@export var maxPress: float = 60.0
@export var followSpeed: float = 8.0

@export_group("Jump")
@export var jumpRadiusScale: float = 0.3
@export var jumpSquashDepth: float = 14.0
@export var jumpRipple: float = 0.15
@export var radiusEase: float = 4.0

@export_group("Landing")
@export var landPress: float = 0.6
@export var landRippleScale: float = 600.0
@export var minLandSpeed: float = 150.0
@export var landCooldown: float = 0.5

@export_group("Ripple wave")
@export var rippleDuration: float = 1.5
@export var maxRipple: float = 1.5
@export var runRipple: float = 0.15
@export var waveRadius: float = 500.0
@export var waveFrequency: float = 90.0
@export var wavePush: float = 25.0

@export_group("Jiggle edges")
@export_range(0.0, 1.0) var edgeLock: float = 1.0

@export_group("Stuck")
@export var stuckJiggleScale: float = 0.2
@export var jiggleScaleEase: float = 6.0

@export_group("Audio")
@export var audioFolder: String = "res://audio"
@export var jumpKeyword: String = "jump"
@export var landKeyword: String = "land"
@export var moveKeyword: String = "mov"
@export var jumpPitchMin: float = 0.85
@export var jumpPitchMax: float = 1.15
@export var landPitchMin: float = 0.8
@export var landPitchMax: float = 1.1
@export var jumpVolumeDb: float = 0.0
@export var landVolumeDb: float = 0.0
@export var moveMaxVolumeDb: float = 0.0
@export var moveFullSpeed: float = 400.0
@export var moveMinSpeed: float = 20.0
@export var moveVolumeEase: float = 12.0
@export var moveStopDelay: float = 0.25

const JIGGLE_TILES := {
	"bouncy": 1.0,
	"extrabouncy": 1.0,
	"sticky": 0.35,
}

const SOUND_TYPES := ["ice", "bouncy", "extrabouncy", "sticky", "hard"]

const JIGGLE_SHADER := """
shader_type canvas_item;

uniform vec2 playerPos = vec2(0.0);
uniform float dentRadius = 300.0;
uniform float dentSoftness = 0.9;
uniform float dentPull = 0.15;
uniform float waveRadius = 500.0;
uniform float press = 0.0;
uniform float strength = 0.0;
uniform float frequency = 25.0;
uniform float push = 25.0;

uniform sampler2D cellData : filter_nearest;
uniform sampler2D reachData : filter_nearest;
uniform vec2 gridOrigin = vec2(0.0);
uniform vec2 cellSize = vec2(100.0);
uniform ivec2 gridMin = ivec2(0);
uniform ivec2 gridSize = ivec2(0);
uniform float edgeLock = 1.0;

float cornerWeight(vec2 world) {
	vec2 q = (world - gridOrigin) / cellSize;
	ivec2 g = ivec2(round(q));
	float w = 1.0;
	float reach = 0.0;
	bool touchesStatic = false;
	bool hasJiggly = false;
	for (int dy = -1; dy <= 0; dy++) {
		for (int dx = -1; dx <= 0; dx++) {
			ivec2 c = g + ivec2(dx, dy) - gridMin;
			if (c.x < 0 || c.y < 0 || c.x >= gridSize.x || c.y >= gridSize.y) {
				continue;
			}
			vec2 d = texelFetch(cellData, c, 0).rg;
			if (d.g > 0.5) {
				if (d.r < 0.01) {
					touchesStatic = true;
				} else {
					hasJiggly = true;
					w = min(w, d.r);
					reach = max(reach, texelFetch(reachData, c, 0).r);
				}
			}
		}
	}
	if (!hasJiggly) {
		return 0.0;
	}
	if (touchesStatic) {
		return w * reach * (1.0 - edgeLock);
	}
	return w * reach;
}

void vertex() {
	vec2 world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	float w = cornerWeight(world);
	vec2 toVert = world - playerPos;
	float dist = length(toVert);
	vec2 dir = dist > 0.001 ? toVert / dist : vec2(0.0, 1.0);

	float dentFall = 1.0 - smoothstep(0.0, dentRadius, dist);
	dentFall = pow(dentFall, dentSoftness);
	VERTEX.y += press * dentFall * w;
	VERTEX.x -= toVert.x / dentRadius * press * dentFall * dentPull * w;

	float waveFall = 1.0 - smoothstep(0.0, waveRadius, dist);
	float wave = sin(TIME * frequency - dist * 0.15);
	VERTEX += dir * wave * waveFall * strength * push * w;
	VERTEX.y += waveFall * strength * push * 0.5 * w;
}
"""

var body: CharacterBody2D
var jiggleShader: Shader
var jiggleMat: ShaderMaterial
var gridTex: ImageTexture
var reachTex: ImageTexture
var matchLayers: Array[TileMapLayer] = []

var gridRect: Rect2i = Rect2i()
var kindData: PackedByteArray = PackedByteArray()
var reachKey: String = ""

var lastFloorType: String = ""
var lastFloorJiggly: bool = false
var wasOnFloorRaw: bool = true
var wasGrounded: bool = true
var groundTimer: float = 0.0
var prevVelocity: Vector2 = Vector2.ZERO
var landCd: float = 0.0

var press: float = 0.0
var pressVel: float = 0.0
var ripple: float = 0.0
var radiusScale: float = 1.0
var dentPos: Vector2
var dentPosReady: bool = false
var jiggleScale: float = 1.0

var soundBank: Dictionary = {}
var jumpPlayer: AudioStreamPlayer
var landPlayer: AudioStreamPlayer
var movePlayer: AudioStreamPlayer
var moveActive: bool = false
var moveType: String = ""
var moveAmount: float = 0.0
var moveIdleTime: float = 0.0

func _ready():
	var node: Node = get_parent()
	while node != null and not (node is CharacterBody2D):
		node = node.get_parent()
	body = node as CharacterBody2D
	if body == null:
		push_error("JIGGLE: this script must be on a node under the player CharacterBody2D.")
		set_physics_process(false)
		return
	prevVelocity = body.velocity

	jiggleShader = Shader.new()
	jiggleShader.code = JIGGLE_SHADER
	jiggleMat = ShaderMaterial.new()
	jiggleMat.shader = jiggleShader

	var root := get_tree().current_scene
	if root == null:
		root = get_tree().root
	if waterTileMap == null:
		waterTileMap = root.find_child(layerNodeName, true, false) as TileMapLayer
	for layerName in matchLayerNames:
		var found := root.find_child(layerName, true, false) as TileMapLayer
		if found != null and found != waterTileMap:
			matchLayers.append(found)

	if waterTileMap == null:
		push_error("JIGGLE: no TileMapLayer found. Assign one or fix layerNodeName.")
	else:
		applyMaterial()
		call_deferred("buildJiggleGrid")

	setupAudio()

func getTileType(layer: TileMapLayer, worldPos: Vector2) -> String:
	if layer.tile_set == null or not layer.tile_set.has_custom_data_layer_by_name("type"):
		return ""
	var cell := layer.local_to_map(layer.to_local(worldPos))
	var data := layer.get_cell_tile_data(cell)
	if data == null:
		return ""
	var value = data.get_custom_data("type")
	return value if value is String else ""

func buildJiggleGrid() -> void:
	var layer := waterTileMap
	if layer == null or layer.tile_set == null:
		return
	var rect := layer.get_used_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var hasType := layer.tile_set.has_custom_data_layer_by_name("type")
	if not hasType:
		push_warning("JIGGLE: TileSet has no 'type' custom data layer, so every tile will jiggle.")

	gridRect = rect
	kindData = PackedByteArray()
	kindData.resize(rect.size.x * rect.size.y)
	kindData.fill(0)

	var img := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RG8)
	for cell in layer.get_used_cells():
		var w: float = 1.0
		if hasType:
			var t := ""
			var data := layer.get_cell_tile_data(cell)
			if data != null:
				var v = data.get_custom_data("type")
				if v is String:
					t = v
			w = float(JIGGLE_TILES.get(t, 0.0))
		var cx: int = cell.x - rect.position.x
		var cy: int = cell.y - rect.position.y
		img.set_pixel(cx, cy, Color(w, 1.0, 0.0))
		kindData[cy * rect.size.x + cx] = 2 if w > 0.01 else 1
	gridTex = ImageTexture.create_from_image(img)

	var zeros := PackedByteArray()
	zeros.resize(rect.size.x * rect.size.y)
	zeros.fill(0)
	reachTex = ImageTexture.create_from_image(Image.create_from_data(rect.size.x, rect.size.y, false, Image.FORMAT_R8, zeros))
	reachKey = ""

	var tilePx := Vector2(layer.tile_set.tile_size)
	var origin := layer.to_global(layer.map_to_local(Vector2i.ZERO) - tilePx * 0.5)
	jiggleMat.set_shader_parameter("cellData", gridTex)
	jiggleMat.set_shader_parameter("reachData", reachTex)
	jiggleMat.set_shader_parameter("gridOrigin", origin)
	jiggleMat.set_shader_parameter("cellSize", tilePx * layer.global_scale)
	jiggleMat.set_shader_parameter("gridMin", rect.position)
	jiggleMat.set_shader_parameter("gridSize", rect.size)

func kindAt(cell: Vector2i) -> int:
	var x: int = cell.x - gridRect.position.x
	var y: int = cell.y - gridRect.position.y
	if x < 0 or y < 0 or x >= gridRect.size.x or y >= gridRect.size.y:
		return 0
	return kindData[y * gridRect.size.x + x]

func touchedJigglyCells(onFloorRaw: bool) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for i in body.get_slide_collision_count():
		var c := body.get_slide_collision(i)
		if c.get_collider() != waterTileMap:
			continue
		var cell := waterTileMap.local_to_map(waterTileMap.to_local(c.get_position() - c.get_normal() * 2.0))
		if kindAt(cell) == 2 and not cells.has(cell):
			cells.append(cell)
	if onFloorRaw:
		var probeCell := waterTileMap.local_to_map(waterTileMap.to_local(body.global_position + feetOffset + Vector2(0.0, footProbe)))
		if kindAt(probeCell) == 2 and not cells.has(probeCell):
			cells.append(probeCell)
	return cells

func updateReach(onFloorRaw: bool) -> void:
	if waterTileMap == null or kindData.is_empty() or reachTex == null:
		return
	var sources := touchedJigglyCells(onFloorRaw)
	if sources.is_empty():
		return
	var parts: Array[String] = []
	for s in sources:
		parts.append(str(s.x, ",", s.y))
	parts.sort()
	var key := ";".join(parts)
	if key == reachKey:
		return
	reachKey = key
	rebuildReach(sources)

func rebuildReach(sources: Array[Vector2i]) -> void:
	var w: int = gridRect.size.x
	var h: int = gridRect.size.y
	var dist := PackedFloat32Array()
	dist.resize(w * h)
	dist.fill(-1.0)
	var queue: Array[Vector2i] = []
	for s in sources:
		var sx: int = s.x - gridRect.position.x
		var sy: int = s.y - gridRect.position.y
		dist[sy * w + sx] = 0.0
		queue.append(Vector2i(sx, sy))

	var head := 0
	while head < queue.size():
		var cur := queue[head]
		head += 1
		var d: float = dist[cur.y * w + cur.x]
		if d >= reachHops:
			continue
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				if ox == 0 and oy == 0:
					continue
				var nx: int = cur.x + ox
				var ny: int = cur.y + oy
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var ni: int = ny * w + nx
				if dist[ni] >= 0.0 or kindData[ni] != 2:
					continue
				dist[ni] = d + 1.0
				queue.append(Vector2i(nx, ny))

	var bytes := PackedByteArray()
	bytes.resize(w * h)
	for i in w * h:
		var v := 0.0
		if dist[i] >= 0.0:
			var t := clampf(dist[i] / maxf(reachHops, 0.001), 0.0, 1.0)
			v = 1.0 - t * t * (3.0 - 2.0 * t)
		bytes[i] = int(round(v * 255.0))
	reachTex.update(Image.create_from_data(w, h, false, Image.FORMAT_R8, bytes))

func applyMaterial() -> void:
	if waterTileMap == null:
		return
	waterTileMap.use_parent_material = false
	if waterTileMap.material != jiggleMat:
		waterTileMap.material = jiggleMat
	for layer in matchLayers:
		layer.use_parent_material = false
		if layer.material != jiggleMat:
			layer.material = jiggleMat

func addRipple(amount: float) -> void:
	ripple = minf(ripple + amount, maxRipple)

func setupAudio() -> void:
	soundBank = {
		"jump": loadSoundBank(jumpKeyword),
		"land": loadSoundBank(landKeyword),
		"move": loadSoundBank(moveKeyword),
	}

	jumpPlayer = AudioStreamPlayer.new()
	landPlayer = AudioStreamPlayer.new()
	movePlayer = AudioStreamPlayer.new()
	add_child(jumpPlayer)
	add_child(landPlayer)
	add_child(movePlayer)

	jumpPlayer.volume_db = jumpVolumeDb
	landPlayer.volume_db = landVolumeDb
	movePlayer.volume_db = -80.0
	movePlayer.finished.connect(onMoveFinished)

func soundTypeOf(fileLower: String) -> String:
	var best := "default"
	var bestLen := 0
	for t in SOUND_TYPES:
		if fileLower.contains(t) and t.length() > bestLen:
			best = t
			bestLen = t.length()
	return best

func loadSoundBank(keyword: String) -> Dictionary:
	var bank := {}
	var dir := DirAccess.open(audioFolder)
	if dir == null:
		push_warning("AUDIO: folder not found: " + audioFolder)
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
		var res: Resource = load(audioFolder.path_join(f))
		if res is AudioStream:
			var s: AudioStream = res as AudioStream
			if keyword == moveKeyword:
				s = makeLoop(s)
			var key := soundTypeOf(lower)
			if not bank.has(key):
				bank[key] = []
			bank[key].append(s)

	if bank.is_empty():
		push_warning("AUDIO: no files containing '" + keyword + "' in " + audioFolder)
	return bank

func makeLoop(s: AudioStream) -> AudioStream:
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

func soundList(action: String, tileType: String) -> Array:
	var bank: Dictionary = soundBank.get(action, {})
	var list: Array = bank.get(tileType, [])
	if list.is_empty():
		list = bank.get("default", [])
	return list

func playSound(player: AudioStreamPlayer, action: String, tileType: String, pitchMin: float, pitchMax: float) -> void:
	if player == null:
		return
	var list := soundList(action, tileType)
	if list.is_empty():
		return
	player.stream = list.pick_random()
	player.pitch_scale = randf_range(pitchMin, pitchMax)
	player.play()

func startMoveStream() -> void:
	moveType = lastFloorType
	var list := soundList("move", moveType)
	if list.is_empty():
		return
	movePlayer.stream = list.pick_random()
	movePlayer.play()

func stopMoveSound() -> void:
	moveActive = false
	moveAmount = 0.0
	if movePlayer != null:
		movePlayer.stop()

func onMoveFinished() -> void:
	if moveActive:
		startMoveStream()

func updateMoveSound(delta: float, grounded: bool, speedX: float) -> void:
	if movePlayer == null:
		return

	var spd: float = absf(speedX)
	var wantsSound: bool = grounded and spd > moveMinSpeed and not soundList("move", lastFloorType).is_empty()

	if wantsSound:
		moveIdleTime = 0.0
		if not moveActive:
			moveActive = true
			moveAmount = 0.0
			startMoveStream()
		elif moveType != lastFloorType:
			startMoveStream()
	else:
		moveIdleTime += delta
		if moveActive and moveIdleTime > moveStopDelay:
			stopMoveSound()
			return

	if moveActive:
		var target: float = clampf(spd / moveFullSpeed, 0.0, 1.0) if wantsSound else 0.0
		moveAmount = lerpf(moveAmount, target, 1.0 - exp(-moveVolumeEase * delta))
		movePlayer.volume_db = linear_to_db(maxf(moveAmount, 0.0001)) + moveMaxVolumeDb

func updateFloorType(onFloorRaw: bool) -> void:
	var found := false
	var tile := ""
	for i in body.get_slide_collision_count():
		var c := body.get_slide_collision(i)
		if c.get_normal().y < -0.5 and c.get_collider() is TileMapLayer:
			tile = getTileType(c.get_collider() as TileMapLayer, c.get_position() - c.get_normal() * 2.0)
			found = true
	if not found and onFloorRaw and waterTileMap != null:
		tile = getTileType(waterTileMap, body.global_position + feetOffset + Vector2(0.0, footProbe))
		found = true
	if found:
		lastFloorType = tile
		lastFloorJiggly = JIGGLE_TILES.has(tile)

func _physics_process(delta: float):
	var vel := body.velocity
	var onFloorRaw := body.is_on_floor()
	landCd = maxf(landCd - delta, 0.0)

	updateFloorType(onFloorRaw)
	updateReach(onFloorRaw)

	if onFloorRaw:
		groundTimer = groundGrace
	else:
		groundTimer = maxf(groundTimer - delta, 0.0)
	var grounded: bool = groundTimer > 0.0

	var jumped: bool = wasOnFloorRaw and not onFloorRaw and vel.y < -minJumpSpeed and Input.is_action_pressed(jumpAction)
	if jumped:
		groundTimer = 0.0
		grounded = false
		playSound(jumpPlayer, "jump", lastFloorType, jumpPitchMin, jumpPitchMax)
		if lastFloorJiggly:
			press = jumpSquashDepth
			pressVel = 0.0
			radiusScale = jumpRadiusScale
			addRipple(jumpRipple)

	var landed: bool = grounded and not wasGrounded and absf(prevVelocity.y) > minLandSpeed
	if landed:
		playSound(landPlayer, "land", lastFloorType, landPitchMin, landPitchMax)
		if lastFloorJiggly and landCd <= 0.0:
			landCd = landCooldown
			dentPos = body.global_position + feetOffset
			radiusScale = 1.0
			pressVel += absf(prevVelocity.y) * landPress
			addRipple(clampf(absf(prevVelocity.y) / landRippleScale, 0.3, maxRipple))
	elif onFloorRaw and absf(vel.x) > 20.0 and lastFloorJiggly:
		addRipple(minf(absf(vel.x) / runRippleSpeed, 1.0) * runRipple * delta)

	wasGrounded = grounded
	wasOnFloorRaw = onFloorRaw
	prevVelocity = vel

	updateJelly(delta, grounded)
	updateMoveSound(delta, grounded, vel.x)

func updateJelly(delta: float, grounded: bool) -> void:
	if debugAlwaysJiggle:
		ripple = absf(sin(Time.get_ticks_msec() / 200.0))
	else:
		ripple *= exp(-3.0 * delta / maxf(rippleDuration, 0.01))
		if ripple < 0.005:
			ripple = 0.0

	var targetScale := 1.0 if grounded else jumpRadiusScale
	radiusScale = lerpf(radiusScale, targetScale, 1.0 - exp(-radiusEase * delta))

	var target := pressDepth if (grounded and lastFloorJiggly) else 0.0
	pressVel += ((target - press) * pressStiffness - pressVel * pressDamping) * delta
	press += pressVel * delta
	press = clampf(press, -maxPress, maxPress)
	if absf(target - press) < 0.05 and absf(pressVel) < 0.5:
		press = target
		pressVel = 0.0

	if waterTileMap == null:
		return

	var feet := body.global_position + feetOffset
	if not dentPosReady:
		dentPos = feet
		dentPosReady = true
	if grounded:
		dentPos = dentPos.lerp(feet, 1.0 - exp(-followSpeed * delta))

	var isStuck: bool = body.get("stuck") == true
	var targetJiggle := stuckJiggleScale if isStuck else 1.0
	jiggleScale = lerpf(jiggleScale, targetJiggle, 1.0 - exp(-jiggleScaleEase * delta))
	var radiusMul: float = maxf(jiggleScale, 0.05)

	applyMaterial()
	jiggleMat.set_shader_parameter("playerPos", dentPos)
	jiggleMat.set_shader_parameter("dentRadius", dentRadius * radiusScale * radiusMul)
	jiggleMat.set_shader_parameter("dentSoftness", dentSoftness)
	jiggleMat.set_shader_parameter("dentPull", dentPull * jiggleScale)
	jiggleMat.set_shader_parameter("waveRadius", waveRadius * radiusScale * radiusMul)
	jiggleMat.set_shader_parameter("press", press * jiggleScale)
	jiggleMat.set_shader_parameter("strength", ripple * jiggleScale)
	jiggleMat.set_shader_parameter("frequency", waveFrequency)
	jiggleMat.set_shader_parameter("edgeLock", edgeLock)
	jiggleMat.set_shader_parameter("push", wavePush * jiggleScale)
