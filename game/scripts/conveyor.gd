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
	mat = StandardMaterial3D.new()
	mat.albedo_texture = T.chevron_tex()
	mat.uv1_scale = Vector3(size.x / 2.0, size.z / 2.0 * (1.0 if dir.z <= 0.0 else -1.0), 1.0)
	mat.roughness = 0.6
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	var belt := T.box(self, size - Vector3(0.0, 0.0, 0.0), Vector3.ZERO, mat)
	belt.material_override = mat
	var rail := T.mat(Color(0.95, 0.75, 0.15), true, 0.5)
	for sx in [-1.0, 1.0]:
		T.box(self, Vector3(0.25, size.y + 0.3, size.z + 0.2), Vector3(sx * (size.x * 0.5 + 0.1), 0.15, 0), rail)


func _process(delta: float) -> void:
	scroll += speed / 2.0 * delta
	mat.uv1_offset.y = scroll
