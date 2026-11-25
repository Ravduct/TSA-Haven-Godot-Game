extends ProgressBar

@onready var player = get_node("/root/level/player")

##Call when player dies
func dead():
	var death_screen = get_node("/root/level/CanvasLayer/deathScreen")
	death_screen.visible = true
	await get_tree().create_timer(2.0).timeout
	player.global_position = player.spawn_position
	death_screen.visible = false
	player.health = 100.0

func _ready():
	var health_value = player.health
	self.value = health_value
	player.health_changed.connect(on_health_change)

func on_health_change(new_health: float):
	self.value = new_health
	if new_health <= 0:
		dead()
