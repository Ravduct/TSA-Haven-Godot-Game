extends ProgressBar

@onready var player = get_node("/root/level/player")

##Call when player's health <= 0
func dead():
	var death_screen = get_node("/root/level/CanvasLayer/deathScreen")
	death_screen.visible = true
	await get_tree().create_timer(2.0).timeout
	player.global_position = player.spawn_position
	death_screen.visible = false
	player.health = 100.0

##Daily tile check for hurt tile and decrease health if on it
var timer = Timer.new()

func _ready():
	add_child(timer)
	timer.wait_time = 0.01 #Time for daily check for hurt tile and decrease health if on it
	timer.one_shot = false # Repeats automatically
	timer.timeout.connect(func():
		if player.tile_type == player.TileType.HURT and player.is_on_floor():
			player.health -= 1 #Amount of health to decrease every wait_time seconds
		self.value = player.health
	)
	timer.start()

	var health_value = player.health
	self.value = health_value
	player.health_changed.connect(on_health_change)

func on_health_change(new_health: float):
	self.value = new_health
	if new_health <= 0:
		dead()
