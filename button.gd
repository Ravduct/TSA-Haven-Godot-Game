extends Node2D

signal pressed
signal released

@export var targets: Array[Node] = []
@export var pressDepth: float = 8.0
@export var pressTime: float = 0.12
@export var releaseTime: float = 0.3
@export var releaseDelay: float = 0.15
@export var latch: bool = false
@export var flagName: String = ""

var top: AnimatableBody2D
var trigger: Area2D
var restY: float = 0.0
var isPressed: bool = false
var bodiesOn: int = 0
var tween: Tween

func _ready():
	var bodies := find_children("*", "AnimatableBody2D", true, false)
	if bodies.is_empty():
		push_error("BUTTON: no AnimatableBody2D found under " + str(get_path()) + ". Add one for the moving top.")
		return
	top = bodies[0] as AnimatableBody2D

	var areas := top.find_children("*", "Area2D", true, false)
	if areas.is_empty():
		push_error("BUTTON: no Area2D found under the top. Add a trigger Area2D as a child of the AnimatableBody2D.")
		return
	trigger = areas[0] as Area2D

	restY = top.position.y
	trigger.body_entered.connect(onEnter)
	trigger.body_exited.connect(onExit)

func isActivator(body: Node) -> bool:
	return body is CharacterBody2D

func onEnter(body: Node) -> void:
	if not isActivator(body):
		return
	bodiesOn += 1
	setPressed(true)

func onExit(body: Node) -> void:
	if not isActivator(body):
		return
	bodiesOn = maxi(bodiesOn - 1, 0)
	if bodiesOn > 0 or latch:
		return
	await get_tree().create_timer(releaseDelay).timeout
	if bodiesOn == 0:
		setPressed(false)

func setPressed(value: bool) -> void:
	if value == isPressed:
		return
	isPressed = value
	moveTop()
	if isPressed:
		pressed.emit()
	else:
		released.emit()
	for target in targets:
		if is_instance_valid(target) and target.has_method("onButton"):
			target.onButton(isPressed)
	if flagName != "":
		var state := get_node_or_null("/root/GameState")
		if state != null:
			state.setFlag(flagName, isPressed)

func moveTop() -> void:
	if tween != null and tween.is_valid():
		tween.kill()
	tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	var goal: float = restY + pressDepth if isPressed else restY
	var time: float = pressTime if isPressed else releaseTime
	tween.tween_property(top, "position:y", goal, time)

func reset() -> void:
	bodiesOn = 0
	setPressed(false)
