extends StaticBody3D
# A conveyor belt: carries whoever stands on it. Chevrons on the belt scroll in the direction it pushes.

const T = preload("res://scripts/toon.gd")

var size := Vector3(6.0, 0.5, 12.0)
var dir := Vector3(0, 0, 1)
var speed := 4.5
var mat: StandardMaterial3D
var scroll := 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	constant_linear_velocity = dir.normalized() * speed
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	add_child(cs)
	# The belt surface is a plane with plain 0..1 UVs (a BoxMesh packs its faces into one texture atlas, which
	# would make the scroll speed and orientation wrong). One chevron tile is 2 m long.
	T.box(self, size, Vector3.ZERO, T.mat(Color(0.16, 0.17, 0.2), false, 0.7))
	mat = StandardMaterial3D.new()
	mat.albedo_texture = T.chevron_tex()
	mat.roughness = 0.6
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.uv1_scale = Vector3(size.x / 2.0, size.z / 2.0 * _flip(), 1.0)
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size.x, size.z)
	plane.mesh = pm
	plane.material_override = mat
	plane.position = Vector3(0, size.y * 0.5 + 0.004, 0)
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plane)
	var rail := T.mat(Color(0.95, 0.75, 0.15), true, 0.5)
	for sx in [-1.0, 1.0]:
		T.box(self, Vector3(0.25, size.y + 0.3, size.z + 0.2), Vector3(sx * (size.x * 0.5 + 0.1), 0.15, 0), rail)


# The chevrons point towards decreasing v, which on a PlaneMesh is -Z; mirror them for belts that push towards +Z.
func _flip() -> float:
	return -1.0 if dir.z > 0.0 else 1.0


func _process(delta: float) -> void:
	# 2 m per tile: scrolling `speed / 2` tiles per second moves the pattern at exactly the belt speed
	scroll += speed / 2.0 * delta
	mat.uv1_offset.y = scroll * _flip()
