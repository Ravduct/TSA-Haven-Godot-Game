extends AnimatableBody2D

func _on_body_entered(body: CharacterBody2D) -> void:
	if body.is_on_floor():
		body.parentPlatform(self)

func _on_body_exited(body: CharacterBody2D) -> void:
	if body.get_parent() == self:
		body.resetParent()
