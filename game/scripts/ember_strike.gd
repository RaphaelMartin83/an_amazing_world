extends Node3D
# An ember flicked by Don Humo: a pulsing red warning circle on the floor, then it drops, then the spot burns for a while.

const T = preload("res://scripts/toon.gd")
const WARN := 1.0
const FALL := 0.18

var radius := 1.6
var burn_time := 3.2
var state := "warn"
var t := 0.0
var disc: MeshInstance3D
var disc_mat: StandardMaterial3D
var ember: MeshInstance3D
var flames: Node3D
var light: OmniLight3D
var cones: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group("hazard")
	disc_mat = StandardMaterial3D.new()
	disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc_mat.albedo_color = Color(1.0, 0.15, 0.05, 0.3)
	disc = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.03
	cyl.radial_segments = 28
	disc.mesh = cyl
	disc.material_override = disc_mat
	disc.position.y = 0.05
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	ember = T.sphere(self, 0.55, Vector3(0, 14.0, 0), T.emissive(Color(1.0, 0.55, 0.1), 3.5))
	ember.visible = false
	flames = Node3D.new()
	flames.visible = false
	add_child(flames)
	for i in 7:
		var a := TAU * i / 7.0
		var r := 0.0 if i == 0 else radius * 0.55
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.38
		cm.height = 1.5
		cm.radial_segments = 8
		cone.mesh = cm
		cone.material_override = T.emissive(Color(1.0, 0.45, 0.08) if i % 2 == 0 else Color(1.0, 0.75, 0.15), 2.2)
		cone.position = Vector3(cos(a) * r, 0.7, sin(a) * r)
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flames.add_child(cone)
		cones.append(cone)
	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.omni_range = 7.0
	light.light_energy = 0.0
	light.position = Vector3(0, 1.2, 0)
	add_child(light)


func _physics_process(delta: float) -> void:
	t += delta
	match state:
		"warn":
			disc_mat.albedo_color.a = 0.28 + 0.3 * sin(t * 14.0)
			disc.scale = Vector3.ONE * (0.8 + 0.2 * minf(t / WARN, 1.0))
			if t >= WARN:
				state = "fall"
				t = 0.0
				ember.visible = true
		"fall":
			ember.position.y = lerpf(14.0, 0.5, clampf(t / FALL, 0.0, 1.0))
			if t >= FALL:
				_impact()
		"burn":
			for i in cones.size():
				var f := 0.75 + 0.35 * sin(t * (11.0 + i * 1.7) + i)
				cones[i].scale = Vector3(1.0, f, 1.0)
				cones[i].position.y = 0.7 * f
			light.light_energy = 1.4 + 0.4 * sin(t * 17.0)
			disc_mat.albedo_color.a = 0.35
			_hurt_if_standing_in_fire()
			if t >= burn_time:
				queue_free()
			elif t > burn_time - 0.5:
				flames.scale = Vector3.ONE * clampf((burn_time - t) / 0.5, 0.05, 1.0)


func _impact() -> void:
	state = "burn"
	t = 0.0
	ember.visible = false
	flames.visible = true
	Sfx.play("boom", 1.8, -10.0)
	Game.shake(0.25)
	var pl: Node3D = Game.player
	if pl and is_instance_valid(pl) and not pl.dead:
		var d := pl.global_position - global_position
		if Vector2(d.x, d.z).length() < radius + 0.1 and d.y < 1.4:
			pl.hurt()


func _hurt_if_standing_in_fire() -> void:
	var pl: Node3D = Game.player
	if pl == null or not is_instance_valid(pl) or pl.dead:
		return
	var d := pl.global_position - global_position
	# only burns on the ground: a jump clears the flames
	if Vector2(d.x, d.z).length() < radius * 0.85 and d.y < 0.7:
		pl.hurt()
