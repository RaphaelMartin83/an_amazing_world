extends CharacterBody3D
# Palmouze in a little red biplane (plane level). Flies on its own along -Z; steer with the move keys/stick.
# The fart button does a BARREL ROLL: a burst of green gas, a speed boost and a moment of safety.
# Implements the same small interface the rest of the game uses for the player (dead, hurt, die, respawn, celebrate ...).

signal died
signal won

const Model = preload("res://scripts/character_model.gd")
const T = preload("res://scripts/toon.gd")

const SPEED_START := 24.0
const SPEED_END := 31.0
const LEVEL_LENGTH := 760.0
const X_LIMIT := 15.0
const Y_MIN := 2.5
const Y_MAX := 17.0
const STEER_SPEED := 13.0
const ROLL_TIME := 0.75
const ROLL_COOLDOWN := 2.2
const SEA_Y := -9.0

var controls_enabled := false
var dead := false
var celebrating := false
var invuln := 0.0
var vel_xy := Vector2.ZERO
var speed := SPEED_START
var roll_t := 0.0
var roll_cd := 0.0
var dead_t := 0.0
var died_emitted := false
var win_t := 0.0
var anim_t := 0.0
var death_reason := ""
var model: Node3D           # (kept for the tests: the pilot)
var plane: Node3D
var pilot: Node3D
var prop: Node3D
var scarf: Array[Node3D] = []
var exhaust: CPUParticles3D
var shadow: MeshInstance3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	add_to_group("player")
	_build()


# ------------------------------------------------------------------ model

func _build() -> void:
	plane = Node3D.new()
	add_child(plane)
	var red := T.mat(Color(0.88, 0.16, 0.12), true, 0.45, null, 0.04)
	var cream := T.mat(Color(0.97, 0.93, 0.8), true, 0.5, null, 0.04)
	var dark := T.mat(Color(0.2, 0.2, 0.24), true, 0.5, null, 0.03)
	var gold := T.mat(Color(1.0, 0.8, 0.25), true, 0.3, null, 0.03)
	var fus := T.capsule(plane, 0.6, 3.8, Vector3(0, 0, 0.1), red)
	fus.rotation.x = PI / 2.0
	T.cylinder(plane, 0.62, 0.62, 0.5, Vector3(0, 0, -1.75), dark, 16).rotation.x = PI / 2.0
	prop = Node3D.new()
	prop.position = Vector3(0, 0, -2.1)
	plane.add_child(prop)
	T.sphere(prop, 0.2, Vector3.ZERO, gold)
	T.box(prop, Vector3(2.1, 0.22, 0.06), Vector3.ZERO, dark)
	T.box(prop, Vector3(0.22, 2.1, 0.06), Vector3.ZERO, dark)
	# two wings (biplane) with struts
	T.box(plane, Vector3(6.2, 0.12, 1.3), Vector3(0, 0.95, -1.05), cream)
	T.box(plane, Vector3(5.6, 0.12, 1.2), Vector3(0, -0.25, -0.95), cream)
	for sx in [-1.0, 1.0]:
		T.box(plane, Vector3(0.5, 0.14, 1.32), Vector3(sx * 2.85, 0.95, -1.05), red)
		T.box(plane, Vector3(0.5, 0.14, 1.22), Vector3(sx * 2.55, -0.25, -0.95), red)
		for dz in [-1.45, -0.65]:
			T.cylinder(plane, 0.05, 0.05, 1.2, Vector3(sx * 1.6, 0.35, dz), dark, 6)
	# tail
	T.box(plane, Vector3(0.12, 0.8, 0.9), Vector3(0, 0.4, 2.0), red)
	T.box(plane, Vector3(2.4, 0.1, 0.8), Vector3(0, 0.1, 2.0), cream)
	# Palmouze in the cockpit, arms up like on a roller coaster
	pilot = Model.new()
	plane.add_child(pilot)
	pilot.build(Game.hero)
	pilot.scale = Vector3.ONE * 0.7
	pilot.position = Vector3(0, 0.4, 0.45)
	model = pilot
	# a red scarf flapping behind him
	for i in 4:
		var seg := T.box(plane, Vector3(0.3, 0.1, 0.55), Vector3(0, 1.75, 1.05 + i * 0.5), T.mat(Color(0.95, 0.2, 0.2), false))
		scarf.append(seg)
	# the engine runs on farts: a trail of green gas
	exhaust = CPUParticles3D.new()
	var puff := SphereMesh.new()
	puff.radius = 0.35
	puff.height = 0.7
	puff.radial_segments = 8
	puff.rings = 4
	exhaust.mesh = puff
	var em := StandardMaterial3D.new()
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	em.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	em.vertex_color_use_as_albedo = true
	exhaust.material_override = em
	exhaust.amount = 40
	exhaust.lifetime = 1.3
	exhaust.local_coords = false
	exhaust.direction = Vector3(0, 0.1, 1)
	exhaust.spread = 18.0
	exhaust.initial_velocity_min = 2.0
	exhaust.initial_velocity_max = 4.0
	exhaust.gravity = Vector3.ZERO
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.5))
	grow.add_point(Vector2(1, 2.6))
	exhaust.scale_amount_curve = grow
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.55, 0.85, 0.12, 0.8))
	ramp.set_color(1, Color(0.45, 0.6, 0.15, 0.0))
	exhaust.color_ramp = ramp
	exhaust.position = Vector3(0, 0.1, 2.5)
	plane.add_child(exhaust)
	# a blob of shadow on the sea of clouds below: the depth cue
	shadow = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.05
	cyl.radial_segments = 20
	shadow.mesh = cyl
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0.1, 0.15, 0.3, 0.35)
	shadow.material_override = sm
	shadow.top_level = true
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)


# ------------------------------------------------------------------ the interface the rest of the game uses

func is_spinning() -> bool:
	return roll_t > 0.0


func is_sliding() -> bool:
	return false


func bounce(_v: float) -> void:
	pass


func respawn(pos: Vector3) -> void:
	dead = false
	died_emitted = false
	dead_t = 0.0
	celebrating = false
	global_position = pos
	vel_xy = Vector2.ZERO
	roll_t = 0.0
	roll_cd = 0.0
	invuln = 2.2
	plane.rotation = Vector3.ZERO
	plane.position = Vector3.ZERO
	reset_physics_interpolation()


func hurt() -> void:
	if dead or invuln > 0.0 or celebrating:
		return
	if Game.has_mask:
		Game.set_mask(false)
		invuln = 1.8
		Sfx.play("hurt")
		Game.shake(0.4)
		return
	die("crash")


func die(reason := "") -> void:
	if dead:
		return
	death_reason = reason
	dead = true
	dead_t = 0.0
	Sfx.play("die")
	Game.shake(0.6)


func celebrate() -> void:
	celebrating = true
	controls_enabled = false
	win_t = 0.0
	Sfx.play("win")
	won.emit()


# ------------------------------------------------------------------ flight

func _physics_process(delta: float) -> void:
	anim_t += delta
	if dead:
		_crash_fall(delta)
		return
	invuln = maxf(0.0, invuln - delta)
	roll_cd = maxf(0.0, roll_cd - delta)
	var input := Vector2.ZERO
	if controls_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if Input.is_action_just_pressed("spin") and roll_cd <= 0.0:
			roll_t = ROLL_TIME
			roll_cd = ROLL_COOLDOWN
			exhaust.amount = 90
			Sfx.play("fart", randf_range(0.9, 1.25))
			Game.shake(0.15)
	var target := Vector2(input.x, -input.y) * STEER_SPEED
	vel_xy = vel_xy.move_toward(target, 48.0 * delta)
	var base := SPEED_START + (SPEED_END - SPEED_START) * clampf(-global_position.z / LEVEL_LENGTH, 0.0, 1.0)
	speed = base + (7.0 if roll_t > 0.0 else 0.0)
	if celebrating:
		win_t += delta
		speed = move_toward(speed, 16.0, win_t * 8.0)
		vel_xy = vel_xy.move_toward(Vector2(0.0, 1.5), 20.0 * delta)
	var p := global_position
	p.x += vel_xy.x * delta
	p.y += vel_xy.y * delta
	p.z -= speed * delta
	if p.x > X_LIMIT or p.x < -X_LIMIT:
		p.x = clampf(p.x, -X_LIMIT, X_LIMIT)
		vel_xy.x = 0.0
	if not celebrating and (p.y > Y_MAX or p.y < Y_MIN):
		p.y = clampf(p.y, Y_MIN, Y_MAX)
		vel_xy.y = 0.0
	global_position = p
	velocity = Vector3(vel_xy.x, vel_xy.y, -speed)
	if roll_t > 0.0:
		roll_t = maxf(0.0, roll_t - delta)
		if roll_t == 0.0:
			exhaust.amount = 40

	# collisions: the body and the two wing tips
	if controls_enabled and invuln <= 0.0 and roll_t <= 0.0 and not celebrating:
		var bank := plane.rotation.z
		var tip := Vector3(cos(bank) * 2.6, -sin(bank) * 2.6, 0.2)
		for o in get_tree().get_nodes_in_group("flight_obstacle"):
			if o.check(p, 1.2) or o.check(p + tip, 0.6) or o.check(p - tip, 0.6):
				hurt()
				break
	_animate(delta)


func _animate(delta: float) -> void:
	var bank_target := -vel_xy.x * 0.045
	var pitch_target := vel_xy.y * 0.03
	plane.rotation.z = lerpf(plane.rotation.z, bank_target, minf(1.0, delta * 8.0))
	plane.rotation.x = lerpf(plane.rotation.x, pitch_target, minf(1.0, delta * 8.0))
	plane.rotation.y = lerpf(plane.rotation.y, -vel_xy.x * 0.012, minf(1.0, delta * 8.0))
	if roll_t > 0.0:
		plane.rotation.z = TAU * (1.0 - roll_t / ROLL_TIME) * -1.0
	if celebrating:
		plane.rotation.z = -win_t * 6.0 if win_t < 1.05 else 0.0
	plane.visible = true if invuln <= 0.0 else (int(anim_t * 18.0) % 2 == 0 or roll_t > 0.0)
	prop.rotation.z += delta * 60.0
	pilot.animate("win" if celebrating else "jump", 0.0, delta)
	for i in scarf.size():
		scarf[i].position = Vector3(sin(anim_t * 14.0 + i * 0.9) * 0.18 * (i + 1) * 0.5, 1.75 + sin(anim_t * 11.0 + i) * 0.05, 1.05 + i * 0.5)
	shadow.global_position = Vector3(global_position.x, SEA_Y + 0.08, global_position.z)
	var h := maxf(global_position.y - SEA_Y, 1.0)
	shadow.scale = Vector3(2.4, 1.0, 3.6) * (3.0 / (1.0 + h * 0.08))
	(shadow.material_override as StandardMaterial3D).albedo_color.a = clampf(0.5 - h * 0.012, 0.12, 0.45)


func _crash_fall(delta: float) -> void:
	dead_t += delta
	plane.rotation.z += delta * 9.0
	plane.rotation.x += delta * 2.0
	global_position += Vector3(vel_xy.x * 0.3, -9.0 * dead_t, -speed * 0.5) * delta
	exhaust.amount = 90
	if dead_t > 1.3 and not died_emitted:
		died_emitted = true
		died.emit()
