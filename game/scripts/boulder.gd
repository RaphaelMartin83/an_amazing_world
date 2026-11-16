extends Node3D
# The giant rolling boulder that chases the hero in the "Boulder Rush" level.

const T = preload("res://scripts/toon.gd")

var radius := 3.2
var speed := 7.2
var dir := Vector3(0, 0, 1)
var active := false
var traveled := 0.0
var start_pos := Vector3.ZERO
var rock: Node3D
var dust: CPUParticles3D


func _ready() -> void:
	start_pos = position
	rock = Node3D.new()
	add_child(rock)
	var tex := T.noise_tex("rock", Color(0.42, 0.38, 0.34), Color(0.7, 0.66, 0.58), 0.09, 128, 7)
	var m := T.mat(Color.WHITE, true, 0.9, tex, 0.08)
	T.sphere(rock, radius, Vector3.ZERO, m)
	# craters / bumps
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 18:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		T.sphere(rock, rng.randf_range(0.4, 0.8), d * radius * 0.96, T.mat(Color(0.5, 0.46, 0.4), false, 0.9))
	dust = CPUParticles3D.new()
	var dm := SphereMesh.new()
	dm.radius = 0.35
	dm.height = 0.7
	dust.mesh = dm
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.85, 0.78, 0.65, 0.55)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust.material_override = dmat
	dust.amount = 30
	dust.lifetime = 1.1
	dust.direction = Vector3(0, 1, -1)
	dust.spread = 40.0
	dust.initial_velocity_min = 2.0
	dust.initial_velocity_max = 5.0
	dust.gravity = Vector3(0, 1, 0)
	dust.scale_amount_min = 0.5
	dust.scale_amount_max = 1.6
	dust.position = Vector3(0, -radius + 0.3, -radius * 0.7)
	add_child(dust)


func reset_to(z: float) -> void:
	active = false
	traveled = 0.0
	position = Vector3(start_pos.x, start_pos.y, z)
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if not active:
		return
	var v := speed + traveled * 0.003
	traveled += v * delta
	position += dir * v * delta
	rock.rotate_x(v * delta / radius)
	var pl: Node3D = Game.player
	if pl == null or not is_instance_valid(pl) or pl.dead or pl.celebrating:
		return
	var d := pl.global_position - global_position
	if d.dot(dir) < radius * 0.8 and Vector2(d.x, d.z).length() < radius * 0.95 and d.y < radius * 1.2:
		pl.die("boulder")
	elif d.dot(dir) < 0.0:
		Game.shake(0.04 * clampf(1.0 - (-d.dot(dir) - radius) / 12.0, 0.0, 1.0))
