extends Node3D
# Collectible beer bottle. Spins, bobs and gets magnetised when the hero is close. (100 = extra life, and he pukes.)

const T = preload("res://scripts/toon.gd")

var base_y := 0.0
var t := 0.0
var taken := false


func _ready() -> void:
	add_to_group("fruit")
	base_y = position.y
	t = randf() * TAU
	var body := Node3D.new()
	body.name = "Body"
	body.scale = Vector3.ONE * 0.85
	add_child(body)
	var glass := T.mat(Color(0.42, 0.20, 0.05), true, 0.15, null, 0.02)
	glass.emission_enabled = true
	glass.emission = Color(0.55, 0.25, 0.03)
	glass.emission_energy_multiplier = 0.4
	var gold := T.mat(Color(1.0, 0.8, 0.2), true, 0.3, null, 0.015)
	var cream := T.mat(Color(0.96, 0.92, 0.78), false, 0.6)
	var bottle := Node3D.new()
	bottle.rotation.z = 0.28
	bottle.position.y = -0.07
	body.add_child(bottle)
	T.cylinder(bottle, 0.115, 0.125, 0.30, Vector3(0, -0.10, 0), glass, 14)      # body
	T.cylinder(bottle, 0.05, 0.115, 0.13, Vector3(0, 0.115, 0), glass, 14)       # shoulder
	T.cylinder(bottle, 0.045, 0.05, 0.17, Vector3(0, 0.265, 0), glass, 12)       # neck
	T.cylinder(bottle, 0.058, 0.058, 0.04, Vector3(0, 0.365, 0), gold, 12)       # cap
	T.cylinder(bottle, 0.128, 0.128, 0.12, Vector3(0, -0.12, 0), cream, 14)      # label
	T.sphere(bottle, 0.025, Vector3(-0.07, -0.02, -0.12), T.emissive(Color(1.0, 0.9, 0.6), 0.8))   # glint


func _physics_process(delta: float) -> void:
	if taken:
		return
	t += delta
	$Body.rotation.y += delta * 3.0
	var pl: Node3D = Game.player
	if pl == null or not is_instance_valid(pl) or pl.dead:
		position.y = base_y + sin(t * 3.0) * 0.08
		return
	var target := pl.global_position + Vector3(0, 0.9, 0)
	var d := target - global_position
	var dist := d.length()
	if dist < 1.15:
		_collect()
		return
	if dist < 3.2:
		global_position += d.normalized() * (7.0 + (3.2 - dist) * 4.0) * delta
	else:
		position.y = base_y + sin(t * 3.0) * 0.08


func _collect() -> void:
	taken = true
	Game.add_fruit(1)
	Sfx.play("fruit", 1.0 + minf(Game.fruit % 12, 11) * 0.03, -4.0)
	queue_free()
