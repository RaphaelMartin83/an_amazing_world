extends CharacterBody3D
# The hero. Crash-style moveset: run, jump, double jump, spin (also glides a bit), slide (+ long jump), body slam.

signal died
signal won

const Model = preload("res://scripts/character_model.gd")

const RUN_SPEED := 9.0
const GROUND_ACCEL := 75.0
const AIR_ACCEL := 38.0
const GRAVITY := 31.0
const FALL_MULT := 1.35
const TERMINAL := -38.0
const JUMP_VEL := 12.2
const DOUBLE_JUMP_VEL := 11.0
const COYOTE := 0.12
const JUMP_BUFFER := 0.13
const SPIN_TIME := 0.46
const SPIN_RADIUS := 1.9
const SLIDE_TIME := 0.55
const SLIDE_SPEED := 14.0
const SLAM_SPEED := -34.0

var model: Node3D
var cam_yaw := 0.0
var controls_enabled := false
var dead := false
var celebrating := false
var invuln := 0.0

var facing := 0.0            # model yaw (radians)
var spin_t := 0.0
var spin_cd := 0.0
var spin_used := false
var spin_angle := 0.0
var slide_t := 0.0
var slide_dir := Vector3.ZERO
var slamming := false
var slam_recover := 0.0
var air_jumps := 1
var coyote := 0.0
var jump_buf := 0.0
var was_on_floor := false
var dead_t := 0.0
var died_emitted := false
var anim_state := "idle"
var last_floor_y := 0.0
var _vy_before := 0.0
var death_reason := ""
var fill: DirectionalLight3D
var gas: CPUParticles3D
var gas_ring: MeshInstance3D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50.0)
	var cs := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = 1.6
	cs.shape = shape
	cs.position = Vector3(0, 0.8, 0)
	cs.name = "Shape"
	add_child(cs)
	model = Model.new()
	model.name = "Model"
	add_child(model)
	model.build(Game.hero)
	_build_gas()
	# Soft fill light that only affects the hero, so his face is never left in shade.
	fill = DirectionalLight3D.new()
	fill.top_level = true
	fill.light_energy = 0.55
	fill.light_color = Color(1.0, 0.95, 0.9)
	fill.light_cull_mask = 2
	fill.shadow_enabled = false
	add_child(fill)
	add_to_group("player")


# The fart attack's visuals: a trail of green gas puffed out behind him as he twirls, plus an expanding ring.
func _build_gas() -> void:
	gas = CPUParticles3D.new()
	var puff := SphereMesh.new()
	puff.radius = 0.4
	puff.height = 0.8
	puff.radial_segments = 12
	puff.rings = 6
	gas.mesh = puff
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.vertex_color_use_as_albedo = true
	gm.albedo_color = Color.WHITE
	gas.material_override = gm
	gas.amount = 90
	gas.lifetime = 1.4
	gas.local_coords = false
	gas.emitting = false
	gas.direction = Vector3(0, 0.25, 1)
	gas.spread = 55.0
	gas.initial_velocity_min = 1.0
	gas.initial_velocity_max = 2.8
	gas.gravity = Vector3(0, 0.6, 0)
	gas.damping_min = 1.5
	gas.damping_max = 2.5
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.7))
	grow.add_point(Vector2(1, 2.8))
	gas.scale_amount_curve = grow
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.55, 0.85, 0.12, 0.95))
	ramp.set_color(1, Color(0.42, 0.6, 0.12, 0.0))
	gas.color_ramp = ramp
	gas.position = Vector3(0, 0.8, 0.38)   # his behind (the model faces -Z)
	model.add_child(gas)

	gas_ring = MeshInstance3D.new()
	var rm := SphereMesh.new()
	rm.radius = 1.0
	rm.height = 2.0
	gas_ring.mesh = rm
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.albedo_color = Color(0.55, 0.85, 0.15, 0.0)
	rmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	gas_ring.material_override = rmat
	gas_ring.position = Vector3(0, 0.9, 0)
	gas_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gas_ring.visible = false
	add_child(gas_ring)


func _fart_burst() -> void:
	gas_ring.visible = true
	gas_ring.scale = Vector3.ONE * 0.4
	var mat: StandardMaterial3D = gas_ring.material_override
	mat.albedo_color.a = 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(gas_ring, "scale", Vector3.ONE * SPIN_RADIUS, SPIN_TIME * 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, SPIN_TIME * 1.1)
	tw.chain().tween_callback(func(): gas_ring.visible = false)


func _process(_delta: float) -> void:
	if gas:
		gas.emitting = spin_t > 0.0
	# The fill light always shines along the camera's view direction, lighting whatever faces the camera.
	var cam := get_viewport().get_camera_3d()
	if cam and fill:
		fill.global_transform = Transform3D(cam.global_transform.basis.orthonormalized(), Vector3.ZERO)


func is_spinning() -> bool:
	return spin_t > 0.0


func is_sliding() -> bool:
	return slide_t > 0.0


func respawn(pos: Vector3) -> void:
	dead = false
	died_emitted = false
	dead_t = 0.0
	celebrating = false
	global_position = pos
	velocity = Vector3.ZERO
	spin_t = 0.0
	slide_t = 0.0
	slamming = false
	slam_recover = 0.0
	if gas_ring:
		gas_ring.visible = false
	invuln = 1.6
	model.flash = 1.6
	$Shape.set_deferred("disabled", false)
	model.rotation = Vector3.ZERO
	reset_physics_interpolation()


func bounce(speed: float) -> void:
	var s := speed
	if Input.is_action_pressed("jump"):
		s *= 1.28
	velocity.y = s
	air_jumps = 1
	spin_used = false
	slamming = false
	model.pop(-0.2)
	Sfx.play("bounce")


func hurt() -> void:
	if dead or invuln > 0.0 or celebrating:
		return
	if Game.has_mask:
		Game.set_mask(false)
		invuln = 1.6
		model.flash = 1.6
		velocity.y = 8.0
		Sfx.play("hurt")
		Game.shake(0.3)
		return
	die("hurt")


func die(reason := "") -> void:
	if dead:
		return
	death_reason = reason
	dead = true
	dead_t = 0.0
	velocity = Vector3(0, 11.0, 0)
	slide_t = 0.0
	spin_t = 0.0
	slamming = false
	$Shape.set_deferred("disabled", true)
	Sfx.play("die")
	Game.shake(0.4)


func celebrate() -> void:
	celebrating = true
	controls_enabled = false
	velocity.x = 0
	velocity.z = 0
	Sfx.play("win")
	won.emit()


func _physics_process(delta: float) -> void:
	if dead:
		_dead_process(delta)
		return

	invuln = maxf(0.0, invuln - delta)
	spin_cd = maxf(0.0, spin_cd - delta)
	var on_floor := is_on_floor()

	var input := Vector2.ZERO
	if controls_enabled and slam_recover <= 0.0:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := Basis(Vector3.UP, cam_yaw) * Vector3(input.x, 0.0, input.y)
	if wish.length() > 1.0:
		wish = wish.normalized()

	# --- landing / ground bookkeeping
	if on_floor:
		coyote = COYOTE
		air_jumps = 1
		spin_used = false
		last_floor_y = global_position.y
		if not was_on_floor:
			_on_land()
	else:
		coyote -= delta

	# --- buffered jump
	jump_buf -= delta
	if controls_enabled and Input.is_action_just_pressed("jump"):
		jump_buf = JUMP_BUFFER
	if jump_buf > 0.0 and slam_recover <= 0.0:
		if coyote > 0.0:
			_jump(JUMP_VEL, false)
		elif air_jumps > 0 and not slamming:
			air_jumps -= 1
			_jump(DOUBLE_JUMP_VEL, true)
	if controls_enabled and Input.is_action_just_released("jump") and velocity.y > 5.0 and not slamming:
		velocity.y *= 0.55

	# --- actions
	if controls_enabled and slam_recover <= 0.0:
		if Input.is_action_just_pressed("spin") and spin_cd <= 0.0 and spin_t <= 0.0 and not slamming and slide_t <= 0.0:
			if on_floor or not spin_used:
				_start_spin(on_floor)
		if Input.is_action_just_pressed("slide") and not slamming:
			if on_floor and slide_t <= 0.0 and spin_t <= 0.0:
				_start_slide(wish)
			elif not on_floor and slide_t <= 0.0:
				_start_slam()

	# --- horizontal movement
	if slamming:
		velocity.x = 0.0
		velocity.z = 0.0
	elif slam_recover > 0.0:
		slam_recover -= delta
		velocity.x = move_toward(velocity.x, 0.0, 60.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 60.0 * delta)
	elif slide_t > 0.0:
		slide_t -= delta
		var sp := lerpf(7.0, SLIDE_SPEED, clampf(slide_t / SLIDE_TIME, 0.0, 1.0))
		if wish.length() > 0.1:
			slide_dir = slide_dir.slerp(wish.normalized(), minf(1.0, 3.0 * delta))
		velocity.x = slide_dir.x * sp
		velocity.z = slide_dir.z * sp
		if not on_floor:
			slide_t = minf(slide_t, 0.15)
	else:
		var target := wish * RUN_SPEED
		var hv := Vector3(velocity.x, 0.0, velocity.z)
		var accel := GROUND_ACCEL if on_floor else AIR_ACCEL
		if not on_floor and hv.length() > RUN_SPEED + 0.5 and target.length() > 0.1:
			accel = 6.0  # keep long-jump momentum
		hv = hv.move_toward(target, accel * delta)
		velocity.x = hv.x
		velocity.z = hv.z

	# --- vertical
	if not on_floor or velocity.y > 0.0:
		var g := GRAVITY * (FALL_MULT if velocity.y < 0.0 else 1.0)
		velocity.y = maxf(velocity.y - g * delta, TERMINAL if not slamming else SLAM_SPEED)
	if spin_t > 0.0 and not on_floor and velocity.y < -2.5:
		velocity.y = -2.5  # spin glide

	# --- spin
	if spin_t > 0.0:
		spin_t -= delta
		spin_angle += delta * TAU / SPIN_TIME * 2.0
		Game.hit_area(global_position, SPIN_RADIUS, "spin", self)
		if spin_t <= 0.0:
			spin_angle = 0.0
			spin_cd = 0.08
	if slide_t > 0.0:
		Game.hit_area(global_position, 1.25, "slide", self)

	# --- move
	_vy_before = velocity.y
	move_and_slide()

	# stomp detection on crates / landing
	if _vy_before < -1.5:
		for i in get_slide_collision_count():
			var c := get_slide_collision(i)
			var col := c.get_collider()
			if col and col.is_in_group("crate") and c.get_normal().y > 0.6:
				if slamming:
					col.hit(self, "slam")
				else:
					col.hit(self, "stomp")
				break

	# kill plane
	if global_position.y < Game.kill_y:
		die("fell")
		return

	# --- facing & animation
	var hvel := Vector2(velocity.x, velocity.z)
	if slide_t > 0.0 and slide_dir.length() > 0.1:
		facing = lerp_angle(facing, atan2(-slide_dir.x, -slide_dir.z), minf(1.0, 18.0 * delta))
	elif wish.length() > 0.15 and not slamming:
		facing = lerp_angle(facing, atan2(-wish.x, -wish.z), minf(1.0, 16.0 * delta))
	model.rotation.y = facing + spin_angle

	if celebrating:
		anim_state = "win"
	elif slamming or slam_recover > 0.0:
		anim_state = "slam"
	elif slide_t > 0.0:
		anim_state = "slide"
	elif spin_t > 0.0:
		anim_state = "spin"
	elif not is_on_floor():
		anim_state = "jump" if velocity.y > 0.5 else "fall"
	elif hvel.length() > 0.8:
		anim_state = "run"
	else:
		anim_state = "idle"
	model.animate(anim_state, hvel.length(), delta)
	was_on_floor = is_on_floor()


func _jump(v: float, is_double: bool) -> void:
	velocity.y = v
	jump_buf = 0.0
	coyote = 0.0
	if slide_t > 0.0:
		# slide jump = long jump
		velocity.x = slide_dir.x * 12.5
		velocity.z = slide_dir.z * 12.5
		slide_t = 0.0
	model.pop(0.22)
	Sfx.play("jump2" if is_double else "jump")


func _start_spin(on_floor: bool) -> void:
	spin_t = SPIN_TIME
	spin_angle = 0.0
	if not on_floor:
		spin_used = true
	Sfx.play("fart", randf_range(0.85, 1.2))
	_fart_burst()


func _start_slide(wish: Vector3) -> void:
	var dir := wish
	if dir.length() < 0.1:
		dir = Vector3(-sin(facing), 0.0, -cos(facing))
	slide_dir = dir.normalized()
	slide_t = SLIDE_TIME
	Sfx.play("slide")


func _start_slam() -> void:
	slamming = true
	velocity = Vector3(0, SLAM_SPEED, 0)
	spin_t = 0.0
	spin_angle = 0.0


func _on_land() -> void:
	if slamming:
		slamming = false
		slam_recover = 0.28
		Game.hit_area(global_position, 2.9, "slam", self)
		Game.shake(0.35)
		Sfx.play("slam")
		model.pop(-0.3)
	elif _vy_before < -6.0:
		model.pop(-0.18)
		Sfx.play("land", 1.0, -10.0)


func _dead_process(delta: float) -> void:
	dead_t += delta
	velocity.y -= GRAVITY * delta
	global_position += velocity * delta
	model.rotation.y += delta * 9.0
	model.animate("dead", 0.0, delta)
	if dead_t > 1.3 and not died_emitted:
		died_emitted = true
		died.emit()
