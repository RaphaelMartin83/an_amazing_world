extends Node3D
# End-of-level portal: a glowing gem inside a ring. Touch it to finish.

const T = preload("res://scripts/toon.gd")

var t := 0.0
var done := false
var gem: Node3D
var ring: Node3D


func _ready() -> void:
	var glow := Color(0.4, 1.0, 0.9)
	ring = T.torus(self, 1.3, 1.6, Vector3(0, 1.8, 0), T.emissive(glow, 1.6))
	ring.rotation.x = PI / 2.0
	T.cylinder(self, 1.9, 2.1, 0.35, Vector3(0, 0.17, 0), T.mat(Color(0.75, 0.78, 0.85)))
	var gm := SphereMesh.new()
	gm.radius = 0.55
	gm.height = 1.5
	gm.radial_segments = 4
	gm.rings = 2
	gem = MeshInstance3D.new()
	gem.mesh = gm
	gem.material_override = T.emissive(Color(1.0, 0.5, 0.9), 2.2)
	gem.position = Vector3(0, 1.8, 0)
	add_child(gem)
	var light := OmniLight3D.new()
	light.light_color = glow
	light.omni_range = 9.0
	light.light_energy = 2.0
	light.position = Vector3(0, 1.8, 0)
	add_child(light)


func _physics_process(delta: float) -> void:
	t += delta
	gem.rotation.y += delta * 2.2
	gem.position.y = 1.8 + sin(t * 2.0) * 0.12
	ring.rotation.z += delta * 0.8
	var pl: Node3D = Game.player
	if done or pl == null or not is_instance_valid(pl) or pl.dead:
		return
	if pl.global_position.distance_to(global_position + Vector3(0, 1.0, 0)) < 2.2:
		done = true
		pl.celebrate()
		Game.level_completed.emit()
