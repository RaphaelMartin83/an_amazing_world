extends Node3D
# A cartoon explosion: light flash, fireball, shockwave ring, sparks, smoke, debris and a scorch mark on the floor.

const T = preload("res://scripts/toon.gd")

var radius := 3.6
var quiet := false       # small blasts (boss hits) don't flash the screen
var floor_y := -1000.0   # world height of the floor under the blast (for the ring and the scorch mark)


func _glow(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _ball(c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 24
	s.rings = 12
	mi.mesh = s
	mi.material_override = _glow(c)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _ready() -> void:
	# --- light flash
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.68, 0.28)
	light.omni_range = radius * 4.0
	light.light_energy = 14.0
	add_child(light)
	var lt := create_tween()
	lt.tween_property(light, "light_energy", 0.0, 0.6).set_ease(Tween.EASE_OUT)

	# --- fireball: a cluster of billowing puffs (orange / red / yellow) around a hot white core
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var tones := [Color(1.0, 0.42, 0.06, 0.95), Color(0.95, 0.22, 0.05, 0.95), Color(1.0, 0.65, 0.1, 0.95)]
	for i in 11:
		var puff := _ball(tones[i % 3])
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.0, 1.0), rng.randf_range(-1, 1)).normalized()
		var reach := radius * rng.randf_range(0.2, 0.55)
		var size := radius * rng.randf_range(0.42, 0.7)
		puff.position = Vector3.ZERO
		puff.scale = Vector3.ONE * 0.2
		var pm: StandardMaterial3D = puff.material_override
		var delay := rng.randf_range(0.0, 0.08)
		var pt := create_tween().set_parallel(true)
		pt.tween_property(puff, "scale", Vector3.ONE * size, 0.28).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		pt.tween_property(puff, "position", dir * reach + Vector3(0, radius * 0.18, 0), 0.5).set_delay(delay).set_ease(Tween.EASE_OUT)
		pt.tween_property(pm, "albedo_color:a", 0.0, 0.4).set_delay(0.3 + delay)
	var core := _ball(Color(1.0, 0.96, 0.7, 1.0))
	core.scale = Vector3.ONE * 0.2
	var cm: StandardMaterial3D = core.material_override
	var ct := create_tween().set_parallel(true)
	ct.tween_property(core, "scale", Vector3.ONE * radius * 0.7, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ct.tween_property(cm, "albedo_color:a", 0.0, 0.28).set_delay(0.1)

	# --- shockwave ring and scorch mark on the floor
	var ground := floor_y - global_position.y + 0.06
	if floor_y < -900.0:
		ground = -0.4
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	tm.rings = 40
	tm.ring_segments = 6
	ring.mesh = tm
	ring.material_override = _glow(Color(1.0, 0.85, 0.5, 0.85))
	ring.position = Vector3(0, ground, 0)
	ring.scale = Vector3(0.4, 1.0, 0.4)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var rm: StandardMaterial3D = ring.material_override
	var rt := create_tween().set_parallel(true)
	rt.tween_property(ring, "scale", Vector3(radius * 1.7, 1.0, radius * 1.7), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rt.tween_property(rm, "albedo_color:a", 0.0, 0.42)

	var scorch := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius * 0.8
	cyl.bottom_radius = radius * 0.8
	cyl.height = 0.02
	cyl.radial_segments = 28
	scorch.mesh = cyl
	scorch.material_override = _glow(Color(0.05, 0.04, 0.04, 0.6))
	scorch.position = Vector3(0, ground - 0.03, 0)
	scorch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(scorch)
	var sm: StandardMaterial3D = scorch.material_override
	var st := create_tween()
	st.tween_property(sm, "albedo_color:a", 0.0, 3.0).set_delay(0.4)

	# --- sparks, smoke, debris
	_particles(40, 0.9, Vector3.UP, 75.0, 8.0, 15.0, Vector3(0, -20, 0), 0.14, T.emissive(Color(1.0, 0.8, 0.25), 3.0), 0.0, true)
	_particles(18, 1.7, Vector3.UP, 55.0, 1.5, 4.5, Vector3(0, 1.0, 0), 0.55, _smoke_mat(), radius * 0.35, false)
	_particles(16, 1.2, Vector3.UP, 85.0, 5.0, 11.0, Vector3(0, -22, 0), 0.24, T.mat(Color(0.8, 0.55, 0.28), false, 0.8), 0.0, true)

	Game.shake(0.25 if quiet else 0.9)
	if not quiet:
		Game.screen_flash.emit(Color(1.0, 0.85, 0.5, 0.5))
	get_tree().create_timer(3.6).timeout.connect(queue_free)


func _smoke_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color.WHITE
	return m


func _particles(count: int, life: float, dir: Vector3, spread: float, vmin: float, vmax: float, grav: Vector3,
		size: float, mat: Material, emit_radius: float, spin: bool) -> void:
	var p := CPUParticles3D.new()
	var mesh: Mesh
	if spin:
		var b := BoxMesh.new()
		b.size = Vector3.ONE * size
		mesh = b
	else:
		var s := SphereMesh.new()
		s.radius = size
		s.height = size * 2.0
		s.radial_segments = 10
		s.rings = 5
		mesh = s
	p.mesh = mesh
	p.material_override = mat
	p.amount = count
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = grav
	if emit_radius > 0.0:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = emit_radius
	if spin:
		p.angular_velocity_min = -500.0
		p.angular_velocity_max = 500.0
		var shrink := Curve.new()
		shrink.add_point(Vector2(0, 1.0))
		shrink.add_point(Vector2(1, 0.1))
		p.scale_amount_curve = shrink
	else:
		var grow := Curve.new()
		grow.add_point(Vector2(0, 0.6))
		grow.add_point(Vector2(1, 2.8))
		p.scale_amount_curve = grow
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.22, 0.2, 0.2, 0.85))
		ramp.set_color(1, Color(0.35, 0.33, 0.32, 0.0))
		p.color_ramp = ramp
		p.damping_min = 1.0
		p.damping_max = 2.0
	add_child(p)
	p.emitting = true
