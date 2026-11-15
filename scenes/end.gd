extends Node2D

@onready var screen: TextureRect = $TextureRect
@onready var credits: RichTextLabel = $RichTextLabel
@onready var back_button: Button = $back

func _ready() -> void:
	ending_animation()

func ending_animation() -> void:
	$Bus.play()

	# Show ending images
	screen.texture = load("res://image assets/end1.png")
	await get_tree().create_timer(3.0).timeout
	screen.texture = load("res://image assets/end2.png")
	await get_tree().create_timer(3.0).timeout
	screen.texture = load("res://image assets/end3.png")

	# Fade to black (use a ColorRect or CanvasModulate if you don't have one)
	var modulate := CanvasModulate.new()
	modulate.color = Color(1, 1, 1, 1)
	add_child(modulate)
	var fade := create_tween()
	fade.tween_property(modulate, "color", Color(0, 0, 0, 1), 2.0)
	await fade.finished

	# Hide image, show credits + button
	screen.visible = false
	credits.visible = true
	back_button.visible = true

	# Scroll credits upward by tweening position
	credits.position.y = get_viewport().get_visible_rect().size.y
	var scroll_duration := 30.0
	var scroll_tween := create_tween()
	scroll_tween.tween_property(
		credits,
		"position:y",
		-credits.size.y,
		scroll_duration
	)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://mainmenu.tscn")   
