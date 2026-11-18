extends Node2D

var lastpos
var lastdirs: Array
var combination: Array

@export var buffer = 20
@export var spells = {
	"star" = [
		[112.5, -112.5, 22.5, 180.0, -22.5],
		[112.5, -112.5, 45.0, 180.0, -45.0],
		[112.5, -90.0, 22.5, 180.0, -22.5],
		[112.5, -90.0, 45.0, 180.0, -45.0]
	],
	"valley" = [
		[-112.5, 112.5],
		[-135.0, 135.0]
	],
	"mountain" = [
		[112.5, -112.5],
		[135.0, -135.0]
	]
}

func _ready():
	var temp = {}
	for k in spells.keys():
		var v = spells[k]
		for l in v:
			temp[l] = str(k)
	spells = temp

func get_direction(v1: Vector2, v2: Vector2):
	if v1 == v2: return false
	var dir = (v2 - v1).normalized()
	var theta = dir.angle()
	theta = round(rad_to_deg(theta)/22.5) * 22.5
	if theta == -180: theta = 180.0
	
	return theta

func getmax(dict: Dictionary):
	var max = 0
	var key
	for i in dict.keys():
		if dict[i] > max: 
			max = dict[i] 
			key = i
	
	return key

func process_spell():
	print(combination)
	if spells.keys().has(combination): print(spells[combination])
	combination.clear()
	lastpos = null
	lastdirs.clear()

func _physics_process(_float) -> void:
	if !Input.is_action_pressed("spellcast"):
		if combination.size() > 0: process_spell()
		return
	var dir = false
	if lastpos:
		dir = get_direction(get_local_mouse_position(), lastpos)
	
	lastpos = get_local_mouse_position()
	
	lastdirs.append(dir)
	if lastdirs.size() > buffer: lastdirs.pop_at(0)
	
	if lastdirs.size() == buffer:
		var lastdir = lastdirs[0]
		var counts = {}
		for d in lastdirs:
			counts[d] = counts[d] + 1 if counts.keys().has(d) else 1
		var sdir = getmax(counts)
		if sdir && ((combination.size() > 0 && combination.back() != sdir) || combination.size() == 0):
			combination.append(sdir)
