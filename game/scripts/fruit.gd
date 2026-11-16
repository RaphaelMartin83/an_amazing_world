extends Node3D
# Collectible fruit (the "mango"). Spins, bobs and gets magnetised when the hero is close.

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
	add_child(body)
	T.sphere(body, 0.26, Vector3.ZERO, T.mat(Color(1.0, 0.62, 0.08), true, 0.4, null, 0.025), Vector3(1.0, 1.1, 1.0))
	T.sphere(body, 0.1, Vector3(-0.1, 0.1, -0.2), T.emissive(Color(1.0, 0.92, 0.6), 0.6))
	var leaf := T.sphere(body, 0.11, Vector3(0.05, 0.3, 0.0), T.mat(Color(0.2, 0.75, 0.25), true, 0.5, null, 0.02), Vector3(1.6, 0.35, 0.8))
	leaf.rotation.z = -0.5


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
