extends Node3D
# THE BREWMASTER: a giant angry beer keg.
#   attacks (always in this order, so they can be learned): foam shots -> leaping slam (shockwave) -> spinning charge
#   weak spot: after a charge he is DIZZY for a few seconds, and only then can he be hurt (fart him or stomp his head).
#   3 hits; every hit makes him faster. Defeating him opens the exit portal and rains beers.

const T = preload("res://scripts/toon.gd")
const Explosion = preload("res://scripts/explosion.gd")
const FoamBall = preload("res://scripts/foam_ball.gd")
const GoalScript = preload("res://scripts/goal.gd")
const FruitScript = preload("res://scripts/fruit.gd")

const BOSS_NAME := "THE BREWMASTER"
const MAX_HP := 3
const RADIUS := 2.1
const HEIGHT := 4.0
const X_LIMIT := 8.8
const Z_NORTH := -25.6
const Z_SOUTH := 7.4
const ATTACKS := ["foam", "slam", "charge"]

var hit_extra := 1.7        # lets the fart reach him despite his size (used by Game.hit_area)
var hp := MAX_HP
var state := "wait"
var t := 0.0
var step := 0
var attack_i := 0
var invuln := 0.0
var flash := 0.0
var shots_left := 0
var shot_cd := 0.0
var slam_from := Vector3.ZERO
var slam_to := Vector3.ZERO
var dash_dir := Vector3.ZERO
var knock_dir := Vector3.BACK
var home := Vector3.ZERO
var seen := {}               # attacks performed so far (used by the tests)
var ring_r := -1.0
var ring_origin := Vector3.ZERO
var ring: MeshInstance3D
var ring_mat: StandardMaterial3D
var rig: Node3D
var arms: Array[Node3D] = []
var legs: Array[Node3D] = []
var stars: Node3D
var mouth_mat: StandardMaterial3D
var wood_mat: StandardMaterial3D
var pupils: Array[Node3D] = []
var _next_boom := 0.0


func _ready() -> void:
	home = position
	add_to_group("enemy")
	add_to_group("boss")
	_build()


# ------------------------------------------------------------------ model

func _build() -> void:
	rig = Node3D.new()
	add_child(rig)
	var plank := T.plank_tex("planks", Color(0.50, 0.32, 0.18), Color(0.72, 0.5, 0.3))
	wood_mat = T.mat(Color(0.62, 0.38, 0.2), true, 0.7, plank, 0.05)
	var gold := T.mat(Color(0.95, 0.75, 0.2), true, 0.25, null, 0.05)
	var foam := T.mat(Color(1.0, 0.97, 0.88), true, 0.6, null, 0.05)
	var dark := T.mat(Color(0.12, 0.05, 0.06), false, 0.5)
	# body: three stacked barrel segments, hoops, foam crown
	T.cylinder(rig, 2.1, 1.75, 1.0, Vector3(0, 1.3, 0), wood_mat, 28)
	T.cylinder(rig, 2.1, 2.1, 0.9, Vector3(0, 2.25, 0), wood_mat, 28)
	T.cylinder(rig, 1.8, 2.1, 1.0, Vector3(0, 3.2, 0), wood_mat, 28)
	for hy in [1.25, 2.25, 3.2]:
		var rr := 1.9 if hy != 2.25 else 2.12
		var band := T.torus(rig, rr - 0.1, rr + 0.12, Vector3(0, hy, 0), gold)
		band.scale = Vector3(1.0, 1.4, 1.0)
	for i in 9:
		var a := TAU * i / 9.0
		T.sphere(rig, 0.65, Vector3(cos(a) * 1.25, 3.85 + sin(i * 2.1) * 0.12, sin(a) * 1.25), foam)
	T.sphere(rig, 1.0, Vector3(0, 4.05, 0), foam)
	for i in 4:
		var a := TAU * i / 4.0 + 0.5
		T.sphere(rig, 0.34, Vector3(cos(a) * 1.9, 3.55, sin(a) * 1.9), foam, Vector3(1.0, 1.6, 1.0))   # drips
	# face (front is -Z)
	for sx in [-1.0, 1.0]:
		var eye := T.sphere(rig, 0.42, Vector3(sx * 0.8, 2.75, -1.85), T.mat(Color.WHITE, true, 0.3, null, 0.03))
		var pupil := Node3D.new()
		pupil.position = Vector3(0, 0, -0.3)
		eye.add_child(pupil)
		T.sphere(pupil, 0.22, Vector3.ZERO, T.mat(Color(0.85, 0.08, 0.05), false, 0.3))
		pupils.append(pupil)
		var brow := T.box(rig, Vector3(1.0, 0.24, 0.24), Vector3(sx * 0.85, 3.3, -1.85), dark)
		brow.rotation = Vector3(0, 0, sx * 0.5)
	mouth_mat = StandardMaterial3D.new()
	mouth_mat.albedo_color = Color(0.25, 0.04, 0.05)
	mouth_mat.emission_enabled = true
	mouth_mat.emission = Color(1.0, 0.65, 0.15)
	mouth_mat.emission_energy_multiplier = 0.0
	T.sphere(rig, 1.0, Vector3(0, 1.85, -1.55), mouth_mat, Vector3(1.15, 0.5, 0.55))
	for i in 7:
		T.box(rig, Vector3(0.22, 0.3, 0.1), Vector3(-0.9 + i * 0.3, 2.12, -2.02), T.mat(Color(1, 1, 0.9), false)).rotation.z = 0.0
	var tap := T.cylinder(rig, 0.2, 0.2, 0.8, Vector3(0, 2.35, -2.2), gold, 12)
	tap.rotation.x = PI / 2.0
	T.box(rig, Vector3(0.7, 0.14, 0.14), Vector3(0, 2.7, -2.5), gold)
	# arms with beer-mug fists
	for sx in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(sx * 2.35, 2.6, 0)
		rig.add_child(arm)
		T.capsule(arm, 0.5, 1.9, Vector3(sx * 0.2, -0.85, 0), wood_mat).rotation.z = sx * 0.2
		var mug := Node3D.new()
		mug.position = Vector3(sx * 0.45, -2.0, 0)
		arm.add_child(mug)
		var glass := T.mat(Color(0.95, 0.65, 0.12), true, 0.1, null, 0.04)
		T.cylinder(mug, 0.62, 0.55, 1.0, Vector3.ZERO, glass, 16)
		T.sphere(mug, 0.64, Vector3(0, 0.5, 0), foam, Vector3(1.0, 0.55, 1.0))
		T.torus(mug, 0.25, 0.42, Vector3(sx * 0.7, 0, 0), glass).rotation.z = PI / 2.0
		arms.append(arm)
	# stubby legs
	for sx in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(sx * 0.95, 0.9, 0.1)
		rig.add_child(leg)
		T.cylinder(leg, 0.6, 0.7, 0.95, Vector3(0, -0.45, 0), wood_mat, 14)
		T.cylinder(leg, 0.72, 0.72, 0.18, Vector3(0, -0.85, 0), gold, 14)
		legs.append(leg)
	# dizzy stars
	stars = Node3D.new()
	stars.position = Vector3(0, 5.0, 0)
	stars.visible = false
	rig.add_child(stars)
	for i in 5:
		T.sphere(stars, 0.22, Vector3.ZERO, T.emissive(Color(1.0, 0.9, 0.2), 2.5))
	# shockwave ring
	ring_mat = StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = Color(1.0, 0.7, 0.2, 0.9)
	ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.93
	tm.outer_radius = 1.0
	tm.rings = 48
	tm.ring_segments = 6
	ring.mesh = tm
	ring.material_override = ring_mat
	ring.top_level = true
	ring.visible = false
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)


# ------------------------------------------------------------------ control

func phase() -> int:
	return 1 + (MAX_HP - hp)


func activate() -> void:
	if state == "wait":
		_set_state("intro")
		Game.boss_health.emit(hp, MAX_HP, BOSS_NAME)


# After the hero dies: the fight resumes with the boss's remaining health.
func reset_fight() -> void:
	if state == "wait" or state == "dead":
		return
	for b in get_tree().get_nodes_in_group("foam_ball"):
		b.queue_free()
	ring_r = -1.0
	ring.visible = false
	position = home
	rig.rotation = Vector3.ZERO
	invuln = 0.0
	_set_state("walk")
	Game.boss_health.emit(hp, MAX_HP, BOSS_NAME)


func _set_state(s: String) -> void:
	state = s
	t = 0.0
	step = 0
	stars.visible = s == "dizzy"
	if s == "dizzy" or s == "walk" or s == "hit":
		mouth_mat.emission_energy_multiplier = 0.0


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
	rig.rotation.y = lerp_angle(rig.rotation.y, atan2(-dir.x, -dir.z), minf(1.0, rate * delta))


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
	wood_mat.emission_enabled = flash > 0.0
	wood_mat.emission = Color(1, 1, 1)
	wood_mat.emission_energy_multiplier = flash * 3.0
	_update_ring(delta)
	var pl := _player()
	match state:
		"intro":
			_face(_dir_to(pl), delta, 3.0)
			if step == 0 and t > 0.5:
				step = 1
				Sfx.play("roar")
				Game.shake(0.5)
			if t > 2.0:
				_set_state("walk")
		"walk":
			_s_walk(delta, pl)
		"foam":
			_s_foam(delta, pl)
		"slam":
			_s_slam(delta, pl)
		"charge":
			_s_charge(delta, pl)
		"dizzy":
			if t >= 3.6 - 0.45 * (phase() - 1):
				_set_state("walk")
		"hit":
			_move(knock_dir * lerpf(9.0, 0.0, clampf(t / 0.5, 0.0, 1.0)) * delta)
			if t > 1.1:
				_set_state("walk")
		"dead":
			_s_dead(delta)
	if state != "dead" and state != "wait":
		_contact(pl)
	_animate(delta)


func _s_walk(delta: float, pl: Node3D) -> void:
	var dir := _dir_to(pl)
	_face(dir, delta, 6.0)
	if pl and (pl.global_position - global_position).length() > 5.5:
		_move(dir * (2.4 + 0.7 * (phase() - 1)) * delta)
	if t >= 1.5 - 0.3 * (phase() - 1):
		var a: String = ATTACKS[attack_i % ATTACKS.size()]
		attack_i += 1
		seen[a] = true
		_set_state(a)


func _s_foam(delta: float, pl: Node3D) -> void:
	_face(_dir_to(pl), delta, 7.0)
	if step == 0:
		mouth_mat.emission_energy_multiplier = minf(t / 0.7, 1.0) * 2.5     # the mouth glows: here it comes
		if t >= 0.75:
			step = 1
			shots_left = 2 + phase()
			shot_cd = 0.0
	elif step == 1:
		shot_cd -= delta
		if shot_cd <= 0.0:
			_fire(pl, shots_left)
			shots_left -= 1
			shot_cd = 0.5 - 0.06 * phase()
			if shots_left <= 0:
				step = 2
				t = 0.0
	elif step == 2:
		mouth_mat.emission_energy_multiplier = maxf(0.0, 2.5 - t * 4.0)
		if t >= 0.9:
			_set_state("walk")


func _fire(pl: Node3D, n: int) -> void:
	var ball := FoamBall.new()
	get_parent().add_child(ball)
	var origin := global_position + Vector3(0, 2.0, 0) + Vector3(-sin(rig.rotation.y), 0, -cos(rig.rotation.y)) * 2.0
	ball.global_position = origin
	var aim := Vector3(0, 0, 1)
	if pl:
		aim = (pl.global_position + Vector3(0, 0.8, 0) - origin).normalized()
	if phase() >= 2:
		aim = aim.rotated(Vector3.UP, (n % 3 - 1) * 0.22)
	ball.velocity = aim * (10.0 + phase())
	Sfx.play("foam")


func _s_slam(delta: float, pl: Node3D) -> void:
	if step == 0:
		_face(_dir_to(pl), delta, 6.0)
		if t >= 0.6:
			slam_from = position
			slam_to = position
			if pl:
				slam_to = Vector3(clampf(pl.global_position.x, -X_LIMIT, X_LIMIT), 0.0, clampf(pl.global_position.z, Z_NORTH, Z_SOUTH))
			step = 1
			t = 0.0
			Sfx.play("bounce", 0.6)
	elif step == 1:
		var u := clampf(t / (1.0 - 0.08 * (phase() - 1)), 0.0, 1.0)
		var e := u * u * (3.0 - 2.0 * u)
		position.x = lerpf(slam_from.x, slam_to.x, e)
		position.z = lerpf(slam_from.z, slam_to.z, e)
		position.y = 5.5 * 4.0 * u * (1.0 - u)
		if u >= 1.0:
			position.y = 0.0
			_land()
			step = 2
			t = 0.0
	elif step == 2:
		if t >= 0.9:
			_set_state("walk")


func _land() -> void:
	Sfx.play("slam")
	Sfx.play("boom", 1.4, -8.0)
	Game.shake(0.8)
	ring_r = 0.5
	ring_origin = position
	var fx := Explosion.new()
	fx.radius = 2.2
	fx.quiet = true
	get_parent().add_child(fx)
	fx.global_position = position + Vector3(0, 0.3, 0)
	var pl := _player()
	if pl:
		var d := pl.global_position - global_position
		if Vector2(d.x, d.z).length() < RADIUS + 0.5 and d.y < 1.2:
			pl.hurt()


func _update_ring(delta: float) -> void:
	if ring_r < 0.0:
		return
	ring_r += (9.5 + 1.5 * (phase() - 1)) * delta
	if ring_r > 16.0:
		ring_r = -1.0
		ring.visible = false
		return
	ring.visible = true
	ring.global_position = ring_origin + Vector3(0, 0.12, 0)
	ring.scale = Vector3(ring_r, 1.0, ring_r)
	ring_mat.albedo_color.a = clampf(1.2 - ring_r / 16.0, 0.0, 0.9)
	var pl := _player()
	if pl:
		var d := pl.global_position - ring_origin
		# only hurts on the ground: jump over it
		if d.y < 0.7 and absf(Vector2(d.x, d.z).length() - ring_r) < 0.85:
			pl.hurt()


func _s_charge(delta: float, pl: Node3D) -> void:
	if step == 0:
		_face(_dir_to(pl), delta, 5.0)
		rig.rotation.z = sin(t * 38.0) * 0.05           # trembling, stamping
		if int(t * 6.0) != int((t - delta) * 6.0):
			Sfx.play("land", 0.7)
		if t >= 0.95:
			dash_dir = _dir_to(pl)
			step = 1
			t = 0.0
			Sfx.play("roar", 1.3)
	else:
		_move(dash_dir * (13.0 + 1.5 * (phase() - 1)) * delta)
		rig.rotation.y += 15.0 * delta
		if _at_wall():
			_crash()
		elif t > 2.8:
			_set_state("dizzy")


func _crash() -> void:
	Sfx.play("boom", 1.0)
	Sfx.play("slam")
	Game.shake(1.0)
	var fx := Explosion.new()
	fx.radius = 3.0
	fx.quiet = true
	get_parent().add_child(fx)
	fx.global_position = position + Vector3(dash_dir.x * 1.5, 1.6, dash_dir.z * 1.5)
	_set_state("dizzy")
	Game.message.emit("HE'S DIZZY!  HIT HIM!", 1.8)


# ------------------------------------------------------------------ damage

# Called by Game.hit_area (fart / slide / slam shockwave / explosions).
func hit(player: Node3D, how: String) -> void:
	if how == "spin" or how == "slide" or how == "slam":
		take_hit(player)


func take_hit(source: Node3D) -> bool:
	if hp <= 0 or state == "dead" or state == "hit" or invuln > 0.0:
		return false
	if state != "dizzy":
		Sfx.play("clank")     # shrugs it off unless he is dizzy
		return false
	hp -= 1
	Game.boss_health.emit(hp, MAX_HP, BOSS_NAME)
	Sfx.play("boss_hit")
	Game.shake(0.7)
	Game.screen_flash.emit(Color(1, 1, 1, 0.35))
	var from := position + Vector3(0, 0, 1)
	if source:
		from = source.global_position
	knock_dir = Vector3(position.x - from.x, 0.0, position.z - from.z)
	knock_dir = knock_dir.normalized() if knock_dir.length() > 0.01 else Vector3(0, 0, -1)
	flash = 0.6
	attack_i = 0
	var fx := Explosion.new()
	fx.radius = 2.4
	fx.quiet = true
	get_parent().add_child(fx)
	fx.global_position = position + Vector3(0, 3.2, 0)
	if hp <= 0:
		_set_state("dead")
		Game.message.emit("THE BREWMASTER IS DONE FOR!", 2.5)
	else:
		_set_state("hit")
		Game.message.emit("%s  -  %d HIT%s TO GO" % ["GOT HIM!", hp, "" if hp == 1 else "S"], 1.8)
	return true


func _contact(pl: Node3D) -> void:
	if pl == null:
		return
	var d := pl.global_position - global_position
	var planar := Vector2(d.x, d.z).length()
	# stomping the foam crown
	if planar < RADIUS + 0.3 and d.y > HEIGHT - 1.4 and d.y < HEIGHT + 1.6 and pl.velocity.y < -0.5:
		if state == "dizzy":
			if take_hit(pl):
				pl.bounce(12.0)
		else:
			pl.bounce(9.0)
			Sfx.play("clank")
		return
	var dangerous := state == "walk" or state == "foam" or (state == "charge" and step == 1) or (state == "slam" and step != 1)
	if dangerous and planar < RADIUS + 0.3 and d.y < HEIGHT - 1.0 and d.y > -1.0 and position.y < 0.6:
		pl.hurt()


# ------------------------------------------------------------------ death

func _s_dead(delta: float) -> void:
	rig.rotation.y += delta * 5.0
	rig.rotation.z = sin(t * 30.0) * 0.08
	flash = 0.15
	_next_boom -= delta
	if _next_boom <= 0.0 and t < 2.6:
		_next_boom = 0.28
		var fx := Explosion.new()
		fx.radius = 2.0
		fx.quiet = true
		get_parent().add_child(fx)
		fx.global_position = position + Vector3(randf_range(-1.5, 1.5), randf_range(0.8, 3.8), randf_range(-1.5, 1.5))
		Sfx.play("boom", randf_range(1.0, 1.5), -6.0)
	if step == 0:
		for b in get_tree().get_nodes_in_group("foam_ball"):
			b.queue_free()
		ring_r = -1.0
		ring.visible = false
		step = 1
	if t >= 2.8 and step == 1:
		step = 2
		_finale()


func _finale() -> void:
	var parent := get_parent()
	var big := Explosion.new()
	big.radius = 6.0
	parent.add_child(big)
	big.global_position = position + Vector3(0, 2.0, 0)
	Sfx.play("boom", 0.7)
	# a shower of beers
	for i in 26:
		var a := TAU * i / 26.0
		var r := 2.0 + (i % 5) * 1.0
		var b := FruitScript.new()
		parent.add_child(b)
		b.global_position = Vector3(position.x + cos(a) * r, 1.0 + (i % 3) * 0.5, position.z + sin(a) * r)
	# the exit portal
	var goal := GoalScript.new()
	parent.add_child(goal)
	goal.global_position = Vector3(0.0, 0.0, home.z)
	Game.boss_hide.emit()
	Game.message.emit("BREWMASTER DEFEATED!", 3.0)
	Sfx.play("win")
	queue_free()


# ------------------------------------------------------------------ animation

func _animate(delta: float) -> void:
	var k := minf(1.0, delta * 10.0)
	var tt := Time.get_ticks_msec() / 1000.0
	var squash := 1.0
	var arm_x := 0.0
	var tilt := 0.0
	match state:
		"walk", "wait", "intro":
			var sp := 6.0 if state == "walk" else 2.0
			tilt = sin(tt * sp) * 0.07
			squash = 1.0 + sin(tt * sp * 2.0) * 0.015
			arm_x = sin(tt * sp) * 0.4
			for i in legs.size():
				legs[i].rotation.x = sin(tt * sp + i * PI) * 0.5 if state == "walk" else 0.0
		"foam":
			tilt = 0.0
			rig.rotation.x = lerpf(rig.rotation.x, -0.25 if step == 0 else 0.15, k)   # lean back, then spit
			arm_x = -0.6
		"slam":
			if step == 0:
				squash = lerpf(1.0, 0.7, clampf(t / 0.6, 0.0, 1.0))
				arm_x = 1.2
			elif step == 1:
				squash = 1.2
				arm_x = -2.2
			else:
				squash = 0.85 + minf(t, 0.4) * 0.35
		"charge":
			squash = 0.9 if step == 0 else 1.0
			arm_x = -1.5 if step == 1 else 0.8
		"dizzy":
			tilt = sin(tt * 4.0) * 0.18
			squash = 1.0 + sin(tt * 8.0) * 0.02
			arm_x = sin(tt * 3.0) * 0.5
			stars.rotation.y += delta * 4.0
			for i in stars.get_child_count():
				var a := TAU * i / stars.get_child_count()
				stars.get_child(i).position = Vector3(cos(a) * 1.6, sin(tt * 5.0 + i) * 0.25, sin(a) * 1.6)
		"hit":
			squash = 1.0 + sin(t * 40.0) * 0.05
			arm_x = -1.0
		"dead":
			squash = 1.0 + sin(t * 25.0) * 0.06
	if state != "foam":
		rig.rotation.x = lerpf(rig.rotation.x, 0.0, k)
	if state != "charge" and state != "dead":
		rig.rotation.z = lerpf(rig.rotation.z, tilt, k)
	rig.scale = Vector3(1.0 / sqrt(maxf(squash, 0.3)), squash, 1.0 / sqrt(maxf(squash, 0.3)))
	for a in arms:
		a.rotation.x = lerpf(a.rotation.x, arm_x, k)
	for p in pupils:
		p.position = Vector3(0, 0, -0.3).rotated(Vector3.FORWARD, tt * 6.0 * (1.0 if state == "dizzy" else 0.0)) if state == "dizzy" else Vector3(0, 0, -0.3)
