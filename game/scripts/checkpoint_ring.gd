extends Node3D
# A glowing ring in the sky. Fly through it to set a checkpoint (the plane respawns here after a crash).

const T = preload("res://scripts/toon.gd")
const RADIUS := 7.0

var taken := false
var missed := false
var ring: MeshInstance3D
var orbit: Node3D
var mat: StandardMaterial3D
var t := 0.0


func _ready() -> void:
	mat = T.emissive(Color(1.0, 0.85, 0.2), 2.5)
	ring = T.torus(self, RADIUS - 0.5, RADIUS, Vector3.ZERO, mat)
	ring.rotation.x = PI / 2.0
	orbit = Node3D.new()
	add_child(orbit)
	for i in 12:
		var a := TAU * i / 12.0
		T.sphere(orbit, 0.35, Vector3(cos(a) * (RADIUS + 0.6), sin(a) * (RADIUS + 0.6), 0), T.emissive(Color(1, 1, 0.7), 3.0))
	var lab := Label3D.new()
	lab.text = "CHECKPOINT"
	lab.font_size = 120
	lab.pixel_size = 0.02
	lab.modulate = Color(1.0, 0.95, 0.6)
	lab.outline_size = 16
	lab.shaded = false
	lab.position = Vector3(0, RADIUS + 1.8, 0)
	add_child(lab)


func _physics_process(delta: float) -> void:
	t += delta
	orbit.rotation.z += delta * 1.5
	if taken or missed:
		return
	var pl: Node3D = Game.player
	if pl == null or not is_instance_valid(pl) or pl.dead:
		return
	if pl.global_position.z < global_position.z:
		var d := Vector2(pl.global_position.x - global_position.x, pl.global_position.y - global_position.y)
		if d.length() <= RADIUS + 1.0:
			taken = true
			mat.albedo_color = Color(0.3, 1.0, 0.5)
			mat.emission = Color(0.3, 1.0, 0.5)
			Game.set_checkpoint(global_position)
			Sfx.play("checkpoint")
		else:
			missed = true
