extends AnimatableBody2D

@export var slideDistance: float = 0.0
@export var slideTime: float = 0.8
@export var startDown: bool = false

var upPosition: Vector2
var downPosition: Vector2
var tween: Tween

func _ready():
	var distance := slideDistance
	if distance <= 0.0:
		distance = wallHeight()
	upPosition = position
	downPosition = position + Vector2(0.0, distance)
	if startDown:
		position = downPosition

func wallHeight() -> float:
	var shapes := find_children("*", "CollisionShape2D", true, false)
	for node in shapes:
		var shapeNode := node as CollisionShape2D
		if shapeNode.shape is RectangleShape2D:
			var rectShape := shapeNode.shape as RectangleShape2D
			return rectShape.size.y * absf(shapeNode.scale.y) * absf(scale.y) + 2.0
	push_warning("WALL: no rectangle collision found, set slideDistance by hand.")
	return 200.0

func onButton(active: bool) -> void:
	var goDown: bool = active != startDown
	slideTo(downPosition if goDown else upPosition)

func slideTo(goal: Vector2) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
	tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position", goal, slideTime)
