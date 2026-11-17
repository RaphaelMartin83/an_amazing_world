extends Node3D
# DON HUMO: a giant lit cigar. Attacks, always in this order so they can be learned:
#   EMBER RAIN  -> red circles on the floor, then burning embers drop there and leave fire patches
#   FLAME SWEEP -> he spins breathing a wall of fire along the floor (jump it). Afterwards he is OVERHEATED:
#                  he slumps on his back, his tip glowing and exposed.
#   ROLLING SMASH -> he lies down and rolls across the arena like a log (sidestep!) into the wall.
# Only an overheated Don Humo can be hurt, and only one way: FART NEXT TO HIS GLOWING TIP (fart + flame = boom).
# Every hit burns the cigar shorter: he shrinks and gets faster. 4 hits.

const T = preload("res://scripts/toon.gd")
const Explosion = preload("res://scripts/explosion.gd")
const EmberStrike = preload("res://scripts/ember_strike.gd")
const GoalScript = preload("res://scripts/goal.gd")
const FruitScript = preload("res://scripts/fruit.gd")

const BOSS_NAME := "DON HUMO"
const MAX_HP := 4
const RADIUS := 1.25
const HEIGHT := 6.4
const HALF_LEN := 2.6          # half the length of the cigar body
const CENTER_H := 3.2          # standing: height of the cigar's centre above the floor
const X_LIMIT := 8.8
const Z_NORTH := -25.6
const Z_SOUTH := 7.4
const BEAM_LEN := 11.0
const ATTACKS := ["rain", "sweep", "roll"]

var hit_extra := 9.0           # lets Game.hit_area reach him; hit() then checks the real distance to the tip
var hp := MAX_HP
var state := "wait"
var t := 0.0
var step := 0
var attack_i := 0
var invuln := 0.0
var flash := 0.0
var waves_left := 0
var wave_cd := 0.0
var dash_dir := Vector3.ZERO
var fall_dir := Vector3(0, 0, 1)
var spin_dir := 1.0
var home := Vector3.ZERO
var seen := {}
var lay := 0.0                 # 0 = standing, 1 = lying down
var lay_target := 0.0
var yaw := 0.0
var roll := 0.0
var death_scale := 1.0
var _clank_cd := 0.0
var _flame_snd := 0.0
var _next_boom := 0.0

var rig: Node3D
var ash: Node3D
var ember_mat: StandardMaterial3D
var mouth_mat: StandardMaterial3D
var body_mat: StandardMaterial3D
var pupils: Array[Node3D] = []
var arms: Array[Node3D] = []
var legs: Array[Node3D] = []
var smoke: CPUParticles3D
var beam: Node3D
var beam_light: OmniLight3D


func _ready() -> void:
	home = position
	add_to_group("enemy")
	add_to_group("boss")
	_build()


# ------------------------------------------------------------------ model (rig origin = the cigar's centre, +Y = its length, face = -Z)

func _build() -> void:
	rig = Node3D.new()
	add_child(rig)
	var leaf := T.noise_tex("tobacco", Color(0.30, 0.16, 0.06), Color(0.56, 0.34, 0.15), 0.09, 128, 31)
	body_mat = T.mat(Color.WHITE, true, 0.75, leaf, 0.05)
	var gold := T.mat(Color(0.95, 0.75, 0.2), true, 0.25, null, 0.04)
	var red := T.mat(Color(0.7, 0.08, 0.08), true, 0.4, null, 0.04)
	var dark := T.mat(Color(0.1, 0.05, 0.04), false, 0.6)
	T.cylinder(rig, 1.25, 1.25, HALF_LEN * 2.0, Vector3.ZERO, body_mat, 28)
	T.sphere(rig, 1.25, Vector3(0, -HALF_LEN, 0), body_mat, Vector3(1.0, 0.5, 1.0))   # rounded foot end
	# paper band
	T.cylinder(rig, 1.29, 1.29, 0.85, Vector3(0, 1.6, 0), red, 28)
	T.cylinder(rig, 1.31, 1.31, 0.12, Vector3(0, 2.05, 0), gold, 28)
	T.cylinder(rig, 1.31, 1.31, 0.12, Vector3(0, 1.15, 0), gold, 28)
	# lit end: glowing ember ring under a cap of ash
	ember_mat = StandardMaterial3D.new()
	ember_mat.albedo_color = Color(0.9, 0.25, 0.05)
	ember_mat.emission_enabled = true
	ember_mat.emission = Color(1.0, 0.45, 0.08)
	ember_mat.emission_energy_multiplier = 1.5
	T.cylinder(rig, 1.2, 1.26, 0.35, Vector3(0, HALF_LEN + 0.12, 0), ember_mat, 28)
	ash = Node3D.new()
	rig.add_child(ash)
	var ash_m := T.mat(Color(0.72, 0.72, 0.76), true, 0.9, null, 0.05)
	T.cylinder(ash, 1.05, 1.22, 1.0, Vector3(0, HALF_LEN + 0.75, 0), ash_m, 24)
	T.sphere(ash, 1.05, Vector3(0, HALF_LEN + 1.25, 0), ash_m, Vector3(1.0, 0.65, 1.0))
	for i in 3:
		T.cylinder(ash, 1.1 + i * 0.03, 1.1 + i * 0.03, 0.06, Vector3(0, HALF_LEN + 0.45 + i * 0.28, 0), T.mat(Color(0.5, 0.5, 0.55), false), 24)
	# face
	for sx in [-1.0, 1.0]:
		var eye := T.sphere(rig, 0.36, Vector3(sx * 0.55, 0.9, -1.0), T.mat(Color.WHITE, true, 0.3, null, 0.03))
		var pupil := Node3D.new()
		pupil.position = Vector3(0, 0, -0.26)
		eye.add_child(pupil)
		T.sphere(pupil, 0.17, Vector3.ZERO, T.mat(Color(0.05, 0.03, 0.03), false, 0.3))
		pupils.append(pupil)
		var brow := T.box(rig, Vector3(0.8, 0.2, 0.2), Vector3(sx * 0.6, 1.35, -1.0), dark)
		brow.rotation = Vector3(0, 0, sx * 0.45)
		var stache := T.capsule(rig, 0.16, 0.95, Vector3(sx * 0.45, 0.25, -1.12), dark)
		stache.rotation = Vector3(0, 0, PI / 2.0 + sx * 0.35)
	mouth_mat = StandardMaterial3D.new()
	mouth_mat.albedo_color = Color(0.25, 0.04, 0.05)
	mouth_mat.emission_enabled = true
	mouth_mat.emission = Color(1.0, 0.6, 0.15)
	mouth_mat.emission_energy_multiplier = 0.0
	T.sphere(rig, 0.55, Vector3(0, -0.2, -1.08), mouth_mat, Vector3(1.1, 0.7, 0.45))
	# stick arms with gloved hands, short legs with big shoes
	for sx in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(sx * 1.35, 0.6, 0)
		rig.add_child(arm)
		T.capsule(arm, 0.2, 1.8, Vector3(sx * 0.15, -0.8, 0), dark)
		T.sphere(arm, 0.42, Vector3(sx * 0.2, -1.75, 0), T.mat(Color(0.97, 0.97, 0.97), true))
		arms.append(arm)
		var leg := Node3D.new()
		leg.position = Vector3(sx * 0.55, -HALF_LEN - 0.35, 0)
		rig.add_child(leg)
		T.capsule(leg, 0.2, 0.9, Vector3(0, -0.25, 0), dark)
		T.sphere(leg, 0.5, Vector3(0, -0.72, -0.18), T.mat(Color(0.05, 0.04, 0.04), true), Vector3(1.0, 0.55, 1.5))
		legs.append(leg)
	# smoke from the lit end
	smoke = CPUParticles3D.new()
	var puff := SphereMesh.new()
	puff.radius = 0.5
	puff.height = 1.0
	puff.radial_segments = 8
	puff.rings = 4
	smoke.mesh = puff
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.vertex_color_use_as_albedo = true
	smoke.material_override = sm
	smoke.amount = 26
	smoke.lifetime = 2.6
	smoke.local_coords = false
	smoke.direction = Vector3.UP
	smoke.spread = 25.0
	smoke.initial_velocity_min = 0.8
	smoke.initial_velocity_max = 1.8
	smoke.gravity = Vector3(0.2, 0.7, 0)
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 2.6))
	smoke.scale_amount_curve = grow
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.75, 0.75, 0.78, 0.55))
	ramp.set_color(1, Color(0.5, 0.5, 0.52, 0.0))
	smoke.color_ramp = ramp
	smoke.position = Vector3(0, HALF_LEN + 1.6, 0)
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rig.add_child(smoke)
	# the flame wall (a child of the boss, not the rig, so it stays flat on the floor)
	beam = Node3D.new()
	beam.visible = false
	add_child(beam)
	var fire_m := T.emissive(Color(1.0, 0.5, 0.1), 2.0)
	fire_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire_m.albedo_color = Color(1.0, 0.5, 0.1, 0.8)
	var core := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.55
	cm.bottom_radius = 0.95
	cm.height = BEAM_LEN
	cm.radial_segments = 12
	core.mesh = cm
	core.material_override = fire_m
	core.rotation = Vector3(PI / 2.0, 0, 0)
	core.position = Vector3(0, 0.8, -(1.2 + BEAM_LEN * 0.5))
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.add_child(core)
	for i in 9:
		var tongue := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.0
		tm.bottom_radius = 0.5
		tm.height = 1.8
		tm.radial_segments = 8
		tongue.mesh = tm
		tongue.material_override = T.emissive(Color(1.0, 0.8, 0.2) if i % 2 == 0 else Color(1.0, 0.4, 0.05), 2.4)
		tongue.position = Vector3(((i % 3) - 1) * 0.5, 1.0, -(1.6 + i * 1.15))
		tongue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.add_child(tongue)
	beam_light = OmniLight3D.new()
	beam_light.light_color = Color(1.0, 0.55, 0.2)
	beam_light.omni_range = 9.0
	beam_light.light_energy = 2.5
	beam_light.position = Vector3(0, 1.5, -5.0)
	beam.add_child(beam_light)
	_apply_pose()


# ------------------------------------------------------------------ pose

func _scale() -> float:
	if state == "dead":
		return death_scale
	return 0.55 + 0.45 * float(hp) / MAX_HP


func _apply_pose() -> void:
	var a := Vector3.UP.slerp(fall_dir, clampf(lay, 0.0, 1.0)).normalized()
	var s := _scale()
	var b := Basis(Quaternion(Vector3.UP, a)) * Basis(Vector3.UP, yaw + roll)
	rig.basis = b.scaled(Vector3.ONE * s)
	rig.position = a * CENTER_H * s + Vector3(0, (RADIUS * s) * (1.0 - a.y), 0)


# World position of the glowing tip while he lies on his back (the fart target).
func tip_pos() -> Vector3:
	var s := _scale()
	return position + fall_dir * (CENTER_H + HALF_LEN) * s + Vector3(0, RADIUS * s, 0)


# ------------------------------------------------------------------ control

func phase() -> int:
	return 1 + (MAX_HP - hp)


func activate() -> void:
	if state == "wait":
		_set_state("intro")
		Game.boss_health.emit(hp, MAX_HP, BOSS_NAME)


func reset_fight() -> void:
	if state == "wait" or state == "dead":
		return
	for h in get_tree().get_nodes_in_group("hazard"):
		h.queue_free()
	beam.visible = false
	position = home
	lay = 0.0
	lay_target = 0.0
	roll = 0.0
	ash.visible = true
	invuln = 0.0
	_set_state("walk")
	Game.boss_health.emit(hp, MAX_HP, BOSS_NAME)


func _set_state(s: String) -> void:
	state = s
	t = 0.0
	step = 0
	if s == "exposed":
		_start_exposed()
	if s == "walk" or s == "hit" or s == "getup":
		mouth_mat.emission_energy_multiplier = 0.0
	if s != "sweep":
		beam.visible = false


func _start_exposed() -> void:
	var to_center := Vector3(-position.x, 0.0, -12.0 - position.z)
	fall_dir = to_center.normalized() if to_center.length() > 1.0 else Vector3(0, 0, 1)
	# face away from the middle so that he topples onto his back (face up), tip pointing into the arena
	yaw = atan2(fall_dir.x, fall_dir.z)
	lay_target = 1.0
	ash.visible = false
	ember_mat.emission_energy_multiplier = 6.0
	Sfx.play("boom", 1.3, -6.0)
	Game.shake(0.5)
	Game.message.emit("HE'S OVERHEATED!  FART AT HIS GLOWING TIP!", 2.4)


func _player() -> Node3D:
	var pl: Node3D = Game.player
	if pl and is_instance_valid(pl) and not pl.dead:
		return pl
	return null


func _dir_to(pl: Node3D) -> Vector3:
	if pl == null:
		return Vector3(0, 0, 1)
	var d := pl.global_position - global_position
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else Vector3(0, 0, 1)


func _face(dir: Vector3, delta: float, rate: float) -> void:
	yaw = lerp_angle(yaw, atan2(-dir.x, -dir.z), minf(1.0, rate * delta))


func _move(v: Vector3) -> void:
	position += v
	position.x = clampf(position.x, -X_LIMIT, X_LIMIT)
	position.z = clampf(position.z, Z_NORTH, Z_SOUTH)


func _at_wall() -> bool:
	return absf(position.x) >= X_LIMIT - 0.01 or position.z <= Z_NORTH + 0.01 or position.z >= Z_SOUTH - 0.01


func _physics_process(delta: float) -> void:
	t += delta
	invuln = maxf(0.0, invuln - delta)
	flash = maxf(0.0, flash - delta)
	_clank_cd = maxf(0.0, _clank_cd - delta)
	body_mat.emission_enabled = flash > 0.0
	body_mat.emission = Color(1, 1, 1)
	body_mat.emission_energy_multiplier = flash * 3.0
	lay = move_toward(lay, lay_target, delta * (2.6 if state != "roll" else 5.0))
	if state != "exposed" and state != "roll" and lay_target > 0.0 and state != "dead" and not (state == "roll"):
		lay_target = 0.0
	ember_mat.emission_energy_multiplier = lerpf(ember_mat.emission_energy_multiplier, 6.0 if state == "exposed" else 1.5, minf(1.0, delta * 4.0))
	var pl := _player()
	match state:
		"intro":
			_face(_dir_to(pl), delta, 3.0)
			if step == 0 and t > 0.5:
				step = 1
				Sfx.play("roar", 0.8)
				Game.shake(0.5)
			if t > 2.0:
				_set_state("walk")
		"walk":
			_s_walk(delta, pl)
		"rain":
			_s_rain(delta, pl)
		"sweep":
			_s_sweep(delta, pl)
		"exposed":
			_s_exposed(delta)
		"getup":
			if lay <= 0.02:
				_set_state("walk")
		"roll":
			_s_roll(delta, pl)
		"hit":
			if t > 1.4:
				_set_state("walk")
		"dead":
			_s_dead(delta)
	if state != "dead" and state != "wait":
		_contact(pl)
	_animate(delta)
	_apply_pose()


func _s_walk(delta: float, pl: Node3D) -> void:
	var dir := _dir_to(pl)
	_face(dir, delta, 5.0)
	if pl and (pl.global_position - global_position).length() > 5.0:
		_move(dir * (2.2 + 0.7 * (phase() - 1)) * delta)
	if t >= 1.4 - 0.25 * (phase() - 1):
		var a: String = ATTACKS[attack_i % ATTACKS.size()]
		attack_i += 1
		seen[a] = true
		_set_state(a)


# ---- ember rain

func _s_rain(delta: float, pl: Node3D) -> void:
	_face(_dir_to(pl), delta, 3.0)
	if step == 0:
		mouth_mat.emission_energy_multiplier = minf(t / 0.7, 1.0) * 1.5
		if t >= 0.8:
			step = 1
			waves_left = 3
			wave_cd = 0.0
			Sfx.play("whoosh")
	elif step == 1:
		wave_cd -= delta
		if wave_cd <= 0.0:
			_drop_wave(pl, 2 + phase())
			waves_left -= 1
			wave_cd = 1.15 - 0.1 * phase()
			if waves_left <= 0:
				step = 2
				t = 0.0
	elif step == 2:
		mouth_mat.emission_energy_multiplier = maxf(0.0, 1.5 - t * 2.0)
		if t >= 1.6:
			_set_state("walk")


func _drop_wave(pl: Node3D, count: int) -> void:
	for i in count:
		var p := Vector3.ZERO
		if i == 0 and pl:
			p = Vector3(pl.global_position.x, 0.0, pl.global_position.z)     # one always aimed at you
		else:
			p = Vector3(randf_range(-X_LIMIT, X_LIMIT), 0.0, randf_range(Z_NORTH + 1.0, Z_SOUTH))
		var e := EmberStrike.new()
		e.burn_time = 3.0 + 0.3 * phase()
		get_parent().add_child(e)
		e.global_position = p
	Sfx.play("foam", 0.6)


# ---- flame sweep

func _s_sweep(delta: float, pl: Node3D) -> void:
	if step == 0:
		_face(_dir_to(pl), delta, 6.0)
		mouth_mat.emission_energy_multiplier = minf(t / 1.0, 1.0) * 3.0
		if t >= 1.0:
			step = 1
			t = 0.0
			spin_dir = 1.0 if randf() < 0.5 else -1.0
			beam.visible = true
			Sfx.play("roar", 1.4)
	elif step == 1:
		var w := 1.5 + 0.3 * (phase() - 1)
		yaw += spin_dir * w * delta
		beam.rotation.y = yaw
		beam.position = Vector3.ZERO
		_flame_snd -= delta
		if _flame_snd <= 0.0:
			_flame_snd = 0.4
			Sfx.play("whoosh", 1.0 + randf() * 0.2, -4.0)
		# the wall of fire hurts on the ground; jump it
		if pl:
			var d := pl.global_position - global_position
			var local := Basis(Vector3.UP, yaw).inverse() * d
			if local.z < -1.2 and local.z > -(1.2 + BEAM_LEN) and absf(local.x) < 0.95 and d.y < 1.5:
				pl.hurt()
		if t >= (TAU * 1.15) / w:
			beam.visible = false
			mouth_mat.emission_energy_multiplier = 0.0
			_set_state("exposed")


func _s_exposed(delta: float) -> void:
	if t >= 4.6 - 0.5 * (phase() - 1):
		Game.message.emit("HE COOLED OFF...", 1.2)
		lay_target = 0.0
		ash.visible = true
		_set_state("getup")


# ---- rolling smash

func _s_roll(delta: float, pl: Node3D) -> void:
	if step == 0:
		_face(_dir_to(pl), delta, 5.0)
		lay_target = 0.0
		yaw += sin(t * 40.0) * 0.01
		if int(t * 6.0) != int((t - delta) * 6.0):
			Sfx.play("land", 0.7)
		if t >= 0.95:
			dash_dir = _dir_to(pl)
			fall_dir = dash_dir.rotated(Vector3.UP, PI / 2.0)     # he lies across his path, like a log
			lay_target = 1.0
			step = 1
			t = 0.0
			Sfx.play("roar", 1.2)
	elif step == 1:
		if lay > 0.8:
			var spd := 11.5 + 1.5 * (phase() - 1)
			_move(dash_dir * spd * delta)
			roll += spd * delta / (RADIUS * _scale()) * 0.8
			if _at_wall():
				_smash()
		if t > 3.2:
			_set_state("getup")
			lay_target = 0.0
	elif step == 2:
		if t >= 1.3:
			lay_target = 0.0
			_set_state("getup")


func _smash() -> void:
	Sfx.play("boom", 1.0)
	Sfx.play("slam")
	Game.shake(1.0)
	var fx := Explosion.new()
	fx.radius = 3.0
	fx.quiet = true
	get_parent().add_child(fx)
	fx.global_position = position + Vector3(dash_dir.x * 1.5, 1.3, dash_dir.z * 1.5)
	step = 2
	t = 0.0


# ------------------------------------------------------------------ damage

# Called by Game.hit_area (fart / slide / slam shockwave / explosions).
func hit(player: Node3D, how: String) -> void:
	if how != "spin":
		return
	var pl: Node3D = player if player else Game.player
	if pl == null or not is_instance_valid(pl):
		return
	if state == "exposed":
		var d := pl.global_position - tip_pos()
		if Vector2(d.x, d.z).length() < 3.4 and absf(d.y) < 3.0:
			ignite(pl)
	elif state != "dead" and _clank_cd <= 0.0:
		var d2 := pl.global_position - global_position
		if Vector2(d2.x, d2.z).length() < RADIUS * _scale() + 3.0:
			_clank_cd = 0.5
			Sfx.play("clank")


func ignite(source: Node3D) -> bool:
	if hp <= 0 or state != "exposed" or invuln > 0.0:
		return false
	hp -= 1
	Game.boss_health.emit(hp, MAX_HP, BOSS_NAME)
	var tip := tip_pos()
	var fx := Explosion.new()
	fx.radius = 4.2
	get_parent().add_child(fx)
	fx.global_position = tip + Vector3(0, 0.4, 0)
	Sfx.play("boss_hit")
	Sfx.play("fart", 1.5, -4.0)
	flash = 0.6
	attack_i = 0
	invuln = 1.5
	if hp <= 0:
		_set_state("dead")
		Game.message.emit("DON HUMO BURNED OUT!", 2.5)
	else:
		lay_target = 0.0
		ash.visible = true
		_set_state("hit")
		Game.message.emit("FART + FLAME = BOOM!   %d HIT%s TO GO" % [hp, "" if hp == 1 else "S"], 2.2)
	return true


func _contact(pl: Node3D) -> void:
	if pl == null:
		return
	var s := _scale()
	var d := pl.global_position - global_position
	if state == "roll" and step == 1 and lay > 0.8:
		# lying across his path: a log RADIUS*s thick, 2*HALF_LEN*s long
		var axis := fall_dir
		var along := d.x * axis.x + d.z * axis.z
		var across := absf(d.x * (-axis.z) + d.z * axis.x)
		if absf(along) < HALF_LEN * s + 0.9 and across < RADIUS * s + 0.5 and d.y < RADIUS * s * 2.2:
			pl.hurt()
		return
	var dangerous := state == "walk" or state == "rain" or state == "sweep" or state == "intro"
	if state == "intro":
		dangerous = false
	if dangerous and lay < 0.2:
		var planar := Vector2(d.x, d.z).length()
		if planar < RADIUS * s + 0.4 and d.y < HEIGHT * s - 0.8 and d.y > -1.0:
			pl.hurt()


# ------------------------------------------------------------------ death

func _s_dead(delta: float) -> void:
	lay_target = 0.0
	flash = 0.15
	death_scale = lerpf(1.0, 0.25, clampf(t / 2.6, 0.0, 1.0)) * (0.55 + 0.45 / MAX_HP)
	yaw += delta * 4.0
	_next_boom -= delta
	if _next_boom <= 0.0 and t < 2.6:
		_next_boom = 0.28
		var fx := Explosion.new()
		fx.radius = 2.0
		fx.quiet = true
		get_parent().add_child(fx)
		fx.global_position = position + Vector3(randf_range(-1.0, 1.0), randf_range(0.5, 4.0), randf_range(-1.0, 1.0))
		Sfx.play("boom", randf_range(1.0, 1.5), -6.0)
	if step == 0:
		for h in get_tree().get_nodes_in_group("hazard"):
			h.queue_free()
		beam.visible = false
		step = 1
	if t >= 2.8 and step == 1:
		step = 2
		_finale()


func _finale() -> void:
	var parent := get_parent()
	var big := Explosion.new()
	big.radius = 6.0
	parent.add_child(big)
	big.global_position = position + Vector3(0, 1.5, 0)
	Sfx.play("boom", 0.7)
	for i in 26:
		var a := TAU * i / 26.0
		var r := 2.0 + (i % 5) * 1.0
		var b := FruitScript.new()
		parent.add_child(b)
		b.global_position = Vector3(position.x + cos(a) * r, 1.0 + (i % 3) * 0.5, position.z + sin(a) * r)
	var goal := GoalScript.new()
	parent.add_child(goal)
	goal.global_position = Vector3(0.0, 0.0, home.z)
	Game.boss_hide.emit()
	Game.message.emit("DON HUMO DEFEATED!", 3.0)
	Sfx.play("win")
	queue_free()


# ------------------------------------------------------------------ animation

func _animate(delta: float) -> void:
	var tt := Time.get_ticks_msec() / 1000.0
	var k := minf(1.0, delta * 10.0)
	var arm_x := 0.0
	smoke.emitting = state != "dead"
	smoke.amount = 60 if state == "exposed" else 26
	match state:
		"walk", "wait", "intro":
			var sp := 6.0 if state == "walk" else 2.0
			arm_x = sin(tt * sp) * 0.5
			for i in legs.size():
				legs[i].rotation.x = sin(tt * sp + i * PI) * 0.6 if state == "walk" else 0.0
		"rain":
			arm_x = -2.4 if step < 2 else 0.0           # arms up, flicking embers
			for i in arms.size():
				arms[i].rotation.z = (1.0 if i == 1 else -1.0) * (0.5 + 0.3 * sin(tt * 20.0)) if step == 1 else 0.0
		"sweep":
			arm_x = -1.2
		"roll":
			arm_x = -1.8
		"exposed":
			arm_x = sin(tt * 3.0) * 0.4
		"dead":
			arm_x = sin(tt * 25.0)
	for a in arms:
		a.rotation.x = lerpf(a.rotation.x, arm_x, k)
		if state != "rain":
			a.rotation.z = lerpf(a.rotation.z, 0.0, k)
	for p in pupils:
		var dizzy := state == "exposed" or (state == "roll" and step == 2)
		p.position = Vector3(0, 0, -0.26).rotated(Vector3.FORWARD, tt * 7.0) if dizzy else Vector3(0, 0, -0.26)
