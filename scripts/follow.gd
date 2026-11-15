extends PathFollow2D

var dir: int = 1
var speed: float = 6

func _process(delta: float):
	progress_ratio += dir * delta / speed
	if progress_ratio >= 1: dir = -1 
	if progress_ratio <= 0: dir = 1
