extends Node3D
# A gem: the reward for bouncing high on a bounce crate (hold jump when you land on it). Worth a bonus of 10 beers.

const T = preload("res://scripts/toon.gd")
const COLORS := [Color(0.3, 0.95, 1.0), Color(1.0, 0.4, 0.85), Color(0.6, 1.0, 0.4), Color(1.0, 0.85, 0.3)]

var t := 0.0
var taken := false
var gem: Node3D


func _ready() -> void:
	add_to_group("gem")
	t = randf() * TAU
	var color: Color = COLORS[int(abs(position.x * 7.0 + position.z * 3.0)) % COLORS.size()]
	var gm := SphereMesh.new()
	gm.radius = 0.5
	gm.height = 1.3
	gm.radial_segments = 4
	gm.rings = 2
	var mi := MeshInstance3D.new()
	mi.mesh = gm
	mi.material_override = T.emissive(color, 2.4)
	gem = mi
	add_child(mi)
	var halo := T.sphere(self, 0.8, Vector3.ZERO, T.emissive(Color(color.r, color.g, color.b, 1.0), 0.0))
	halo.visible = false
	var l := OmniLight3D.new()
	l.light_color = color
	l.omni_range = 5.0
	l.light_energy = 1.2
	l.shadow_enabled = false
	add_child(l)


func _physics_process(delta: float) -> void:
	if taken:
		return
	t += delta
	gem.rotation.y += delta * 2.6
	gem.position.y = sin(t * 2.4) * 0.15
	var pl: Node3D = Game.player
	if pl == null or not is_instance_valid(pl) or pl.dead:
		return
	if pl.global_position.distance_to(global_position - Vector3(0, 0.9, 0)) < 1.6:
		taken = true
		Game.add_gem()
		queue_free()
