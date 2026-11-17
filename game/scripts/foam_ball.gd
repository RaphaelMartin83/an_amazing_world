extends Node3D
# A glob of foam spat by the Brewmaster. Hurts on contact; a fart pops it harmlessly.

const T = preload("res://scripts/toon.gd")

var velocity := Vector3.ZERO
var life := 4.5
var done := false
var blob: Node3D


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("foam_ball")
	blob = Node3D.new()
	add_child(blob)
	var foam := T.mat(Color(1.0, 0.97, 0.88), true, 0.6, null, 0.04)
	T.sphere(blob, 0.5, Vector3.ZERO, foam)
	for i in 5:
		var a := TAU * i / 5.0
		T.sphere(blob, 0.22, Vector3(cos(a) * 0.38, sin(a * 2.0) * 0.3, sin(a) * 0.38), foam)
	T.sphere(blob, 0.12, Vector3(-0.15, 0.2, -0.4), T.emissive(Color(1.0, 0.9, 0.5), 0.6))


func hit(_player: Node3D, _how: String) -> void:
	_burst(false)


func _physics_process(delta: float) -> void:
	if done:
		return
	global_position += velocity * delta
	blob.rotation += Vector3(3.0, 5.0, 2.0) * delta
	life -= delta
	var pl: Node3D = Game.player
	if pl and is_instance_valid(pl) and not pl.dead:
		var d: Vector3 = pl.global_position + Vector3(0, 0.9, 0) - global_position
		if d.length() < 1.15:
			pl.hurt()
			_burst(true)
			return
	var p := global_position
	if life <= 0.0 or absf(p.x) > 10.5 or p.z < -27.5 or p.z > 12.0 or p.y < 0.25:
		_burst(true)


func _burst(on_hit: bool) -> void:
	if done:
		return
	done = true
	remove_from_group("enemy")
	Sfx.play("foam", 0.7)
	var fx := CPUParticles3D.new()
	var s := SphereMesh.new()
	s.radius = 0.16
	s.height = 0.32
	s.radial_segments = 8
	s.rings = 4
	fx.mesh = s
	fx.material_override = T.mat(Color(1.0, 0.97, 0.88), false, 0.6)
	fx.amount = 18
	fx.one_shot = true
	fx.explosiveness = 1.0
	fx.lifetime = 0.7
	fx.spread = 180.0
	fx.initial_velocity_min = 2.0
	fx.initial_velocity_max = 5.0
	fx.gravity = Vector3(0, -12, 0)
	fx.emitting = true
	get_parent().add_child(fx)
	fx.global_position = global_position
	get_tree().create_timer(1.2).timeout.connect(fx.queue_free)
	queue_free()
