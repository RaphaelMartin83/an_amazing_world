extends Node3D
# Chase camera: follows the hero from a fixed angle (Crash-style), with smoothing and shake.

var target: Node3D
var camera: Camera3D
var offset := Vector3(0, 4.6, 8.6)
var look_offset := Vector3(0, 1.3, -3.0)
var follow := Vector3.ZERO
var shake_amount := 0.0
var fov_boost := 0.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.near = 0.1
	camera.far = 600.0
	camera.current = true
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(camera)
	Game.camera_rig = self


func snap() -> void:
	if target:
		follow = target.global_position
		_update(0.0, true)


func shake(a: float) -> void:
	shake_amount = maxf(shake_amount, a)


func _process(delta: float) -> void:
	_update(delta, false)


func _update(delta: float, instant: bool) -> void:
	if target == null:
		return
	var tp := target.global_position
	var k := 1.0 if instant else 1.0 - exp(-delta * 5.0)
	var ky := 1.0 if instant else 1.0 - exp(-delta * 3.2)
	follow.x = lerpf(follow.x, tp.x, k)
	follow.z = lerpf(follow.z, tp.z, 1.0 if instant else 1.0 - exp(-delta * 9.0))
	follow.y = lerpf(follow.y, tp.y, ky)
	var pos := follow + offset
	var look := follow + look_offset
	var shake_off := Vector3.ZERO
	if shake_amount > 0.001:
		shake_off = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake_amount
		shake_amount = move_toward(shake_amount, 0.0, delta * 1.6)
	camera.global_transform = _look(pos + shake_off, look)


func _look(from: Vector3, to: Vector3) -> Transform3D:
	var fwd := (to - from).normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var up := right.cross(fwd).normalized()
	return Transform3D(Basis(right, up, -fwd), from)
