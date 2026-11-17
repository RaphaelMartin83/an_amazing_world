extends Node3D
# The finish arch of the plane level: a huge rainbow ring. Flying through it (anywhere inside) completes the level.

const T = preload("res://scripts/toon.gd")
const RADIUS := 11.0

var done := false
var t := 0.0
var rings: Array[MeshInstance3D] = []
var orbit: Node3D


func _ready() -> void:
	var colors := [Color(1.0, 0.25, 0.25), Color(1.0, 0.6, 0.15), Color(1.0, 0.9, 0.2), Color(0.3, 0.85, 0.35), Color(0.3, 0.6, 1.0), Color(0.65, 0.4, 1.0)]
	for i in colors.size():
		var r := T.torus(self, RADIUS - 0.4 - i * 0.55, RADIUS + 0.1 - i * 0.55, Vector3.ZERO, T.emissive(colors[i], 1.8))
		r.rotation.x = PI / 2.0
		rings.append(r)
	orbit = Node3D.new()
	add_child(orbit)
	for i in 24:
		var a := TAU * i / 24.0
		T.sphere(orbit, 0.45, Vector3(cos(a) * (RADIUS + 1.0), sin(a) * (RADIUS + 1.0), 0), T.emissive(Color.from_hsv(float(i) / 24.0, 0.7, 1.0), 3.0))
	var lab := Label3D.new()
	lab.text = "FINISH"
	lab.font_size = 200
	lab.pixel_size = 0.022
	lab.modulate = Color(1, 1, 1)
	lab.outline_size = 26
	lab.shaded = false
	lab.position = Vector3(0, RADIUS + 3.5, 0)
	add_child(lab)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.9, 0.7)
	light.omni_range = 40.0
	light.light_energy = 2.0
	add_child(light)


func _physics_process(delta: float) -> void:
	t += delta
	orbit.rotation.z = t * 1.2
	for i in rings.size():
		rings[i].scale = Vector3.ONE * (1.0 + 0.02 * sin(t * 3.0 + i))
	if done:
		return
	var pl: Node3D = Game.player
	if pl == null or not is_instance_valid(pl) or pl.dead:
		return
	if pl.global_position.z < global_position.z:
		done = true
		pl.celebrate()
		Game.level_completed.emit()
