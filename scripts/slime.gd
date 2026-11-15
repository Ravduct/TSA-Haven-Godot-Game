extends CharacterBody2D

@export var speed: int = 150

enum direction {
	UP,
	LEFT,
	RIGHT,
	DOWN,
	CLOCKWISE,
	COUNTERCLOCKWISE	
}

var dir = direction.DOWN
var movingdir = direction.COUNTERCLOCKWISE
var player

func _ready():
	turnaround()
	player = get_node("/root/Node2D/player")

func turn(targetdir: direction):
	dir = targetdir
	rotation += PI / 2 * (-1 if movingdir == direction.COUNTERCLOCKWISE else 1)

func turnaround():
	rotation += PI
	movingdir = direction.CLOCKWISE if movingdir == direction.COUNTERCLOCKWISE else direction.COUNTERCLOCKWISE
	$hitbox/sprite.flip_v = !$hitbox/sprite.flip_v

func _physics_process(delta: float) -> void:
	velocity = transform.x * speed
	var collision = move_and_collide(velocity * delta)
	
	if collision:
		if movingdir == direction.COUNTERCLOCKWISE:
			match dir:
				direction.DOWN:
					turn(direction.RIGHT)
				direction.RIGHT:
					turn(direction.UP)
				direction.UP:
					turn(direction.LEFT)
				direction.LEFT:
					turn(direction.DOWN)
		else:
			match dir:
				direction.DOWN:
					turn(direction.LEFT)
				direction.LEFT:
					turn(direction.UP)
				direction.UP:
					turn(direction.RIGHT)
				direction.RIGHT:
					turn(direction.DOWN)
