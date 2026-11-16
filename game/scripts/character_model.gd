extends Node3D
# Builds the cartoon hero out of primitives from a config dictionary (see friend_config.gd),
# and animates it procedurally (idle / run / jump / fall / spin / slide / slam / win / dead).

const T = preload("res://scripts/toon.gd")

var cfg: Dictionary
var body: Node3D          # everything that tilts/bobs
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var eye_l: Node3D
var eye_r: Node3D
var phase := 0.0
var blink_t := 2.0
var squash := 0.0
var flash := 0.0


func build(c: Dictionary) -> void:
	cfg = c
	for ch in get_children():
		ch.queue_free()
	var build_w: float = c.build
	var skin: Color = c.skin
	var skin_m := T.mat(skin, true, 0.55)
	var shirt_m := T.mat(c.shirt)
	var pants_m := T.mat(c.pants)
	var shoe_m := T.mat(c.shoes)
	var glove_m := T.mat(c.gloves)
	var hair_m := T.mat(c.hair_color, true, 0.5)

	body = Node3D.new()
	add_child(body)
	scale = Vector3.ONE * 0.85 * float(c.height)

	# --- legs (pivot at hip) ---
	leg_l = _leg(-0.2 * build_w, pants_m, shoe_m)
	leg_r = _leg(0.2 * build_w, pants_m, shoe_m)

	# --- torso ---
	var torso := T.capsule(body, 0.31 * build_w, 0.78, Vector3(0, 0.98, 0), shirt_m)
	torso.scale = Vector3(1.0, 1.0, 0.85)
	T.cylinder(body, 0.32 * build_w, 0.31 * build_w, 0.18, Vector3(0, 0.66, 0), pants_m)
	if str(c.shirt_text) != "":
		var lab := Label3D.new()
		lab.text = str(c.shirt_text)
		lab.font_size = 96
		lab.pixel_size = 0.0045
		lab.outline_size = 14
		lab.modulate = Color.WHITE
		lab.outline_modulate = Color(0.1, 0.05, 0.1)
		lab.position = Vector3(0, 1.0, -0.27)
		lab.shaded = false
		body.add_child(lab)

	# --- arms (pivot at shoulder) ---
	arm_l = _arm(-0.42 * build_w, skin_m, glove_m, shirt_m)
	arm_r = _arm(0.42 * build_w, skin_m, glove_m, shirt_m)

	# --- head ---
	var hs: float = c.head_scale
	var R := 0.44 * hs
	head = Node3D.new()
	head.position = Vector3(0, 1.38 + R * 0.92, 0)
	body.add_child(head)
	var fw: float = c.face_width
	T.sphere(head, R, Vector3.ZERO, skin_m, Vector3(fw, 1.0, 1.0))
	T.sphere(head, R * 0.12 * float(c.nose), Vector3(0, -0.1 * R, -0.97 * R), T.mat(skin.darkened(0.04), false, 0.5), Vector3(1, 0.9, 0.9))
	# ears
	for sx in [-1.0, 1.0]:
		T.sphere(head, 0.14 * R * float(c.ears), Vector3(sx * 0.98 * R * fw, -0.02 * R, 0.0), skin_m, Vector3(0.6, 1.0, 1.0))
	_eyes(R, fw)
	_mouth(R)
	_hair(R, fw, hair_m)
	_beard(R, fw, hair_m, skin)
	if c.glasses:
		_glasses(R, fw)
	_accessory(R, fw)
	_no_shadow_receive(body)


# Cartoon look: the hero is evenly lit (his shadow still falls on the ground).
func _no_shadow_receive(n: Node) -> void:
	for ch in n.get_children():
		if ch is MeshInstance3D:
			ch.layers = 1 | 2   # layer 2 is lit by the hero-only fill light (see player.gd)
			if ch.material_override is BaseMaterial3D:
				ch.material_override.disable_receive_shadows = true
		_no_shadow_receive(ch)


func _leg(x: float, pants_m: Material, shoe_m: Material) -> Node3D:
	var p := Node3D.new()
	p.position = Vector3(x, 0.66, 0)
	body.add_child(p)
	T.capsule(p, 0.16 * float(cfg.build), 0.62, Vector3(0, -0.3, 0), pants_m)
	T.sphere(p, 0.19, Vector3(0, -0.58, -0.07), shoe_m, Vector3(1.0, 0.7, 1.55))
	return p


func _arm(x: float, skin_m: Material, glove_m: Material, shirt_m: Material) -> Node3D:
	var p := Node3D.new()
	p.position = Vector3(x, 1.22, 0)
	body.add_child(p)
	T.capsule(p, 0.1 * float(cfg.build), 0.52, Vector3(0, -0.22, 0), skin_m)
	T.sphere(p, 0.15, Vector3(0, 0.0, 0), shirt_m)  # shoulder / sleeve
	T.sphere(p, 0.15, Vector3(0, -0.5, 0), glove_m)
	return p


func _eyes(R: float, fw: float) -> void:
	var white_m := T.mat(Color.WHITE, true, 0.3, null, 0.02)
	var iris_m := T.mat(cfg.eye_color, false, 0.3)
	var pupil_m := T.mat(Color(0.02, 0.02, 0.04), false, 0.2)
	var brow_m := T.mat(cfg.hair_color, false, 0.6)
	for sx in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(sx * 0.34 * R * fw, 0.1 * R, -0.8 * R)
		head.add_child(pivot)
		T.sphere(pivot, 0.2 * R, Vector3.ZERO, white_m)
		T.sphere(pivot, 0.12 * R, Vector3(sx * 0.05 * R, 0, -0.13 * R), iris_m)
		T.sphere(pivot, 0.065 * R, Vector3(sx * 0.055 * R, 0, -0.2 * R), pupil_m)
		T.sphere(pivot, 0.025 * R, Vector3(sx * 0.085 * R, 0.04 * R, -0.235 * R), T.emissive(Color.WHITE, 1.0))
		if sx < 0:
			eye_l = pivot
		else:
			eye_r = pivot
		# eyebrow
		var b := T.box(head, Vector3(0.3 * R, 0.07 * R * float(cfg.brow), 0.07 * R), Vector3(sx * 0.35 * R * fw, 0.4 * R, -0.84 * R), brow_m)
		b.rotation.z = sx * -0.16
		b.rotation.y = sx * 0.3


func _mouth(R: float) -> void:
	var dark := T.mat(Color(0.35, 0.05, 0.08), false, 0.4)
	var tongue := T.mat(Color(0.9, 0.35, 0.4), false, 0.4)
	var teeth := T.mat(Color(1, 1, 1), false, 0.3)
	T.sphere(head, 0.3 * R, Vector3(0, -0.43 * R, -0.82 * R), dark, Vector3(1.0, 0.42, 0.45))
	T.sphere(head, 0.14 * R, Vector3(0, -0.5 * R, -0.84 * R), tongue, Vector3(1.0, 0.5, 0.4))
	T.box(head, Vector3(0.44 * R, 0.07 * R, 0.05 * R), Vector3(0, -0.375 * R, -0.935 * R), teeth)


func _hair(R: float, fw: float, m: Material) -> void:
	match str(cfg.hair_style):
		"short":
			T.sphere(head, R * 1.07, Vector3(0, 0.2 * R, 0.14 * R), m, Vector3(fw, 0.92, 1.0))
		"messy":
			# cap + volume on top + a side-swept fringe and a few stray tufts
			T.sphere(head, R * 1.07, Vector3(0, 0.2 * R, 0.16 * R), m, Vector3(fw, 0.92, 1.0))
			var tops := [
				Vector3(-0.55, 0.92, -0.05), Vector3(-0.2, 1.02, -0.2), Vector3(0.25, 1.05, -0.1),
				Vector3(0.6, 0.9, -0.05), Vector3(-0.35, 0.98, 0.3), Vector3(0.2, 1.0, 0.3), Vector3(0.0, 1.1, 0.05)]
			for p in tops:
				T.sphere(head, 0.33 * R, Vector3(p.x * R * fw, p.y * R, p.z * R), m, Vector3(1.0, 0.9, 1.1))
			var fringe := T.capsule(head, 0.2 * R, 1.0 * R, Vector3(0.12 * R, 0.66 * R, -0.8 * R), m)
			fringe.rotation = Vector3(0.1, 0.0, 1.05)
			var lock := T.capsule(head, 0.14 * R, 0.55 * R, Vector3(-0.72 * R * fw, 0.45 * R, -0.5 * R), m)
			lock.rotation = Vector3(0.2, 0.3, -0.35)
			for i in 3:
				var tuft := T.cylinder(head, 0.0, 0.17 * R, 0.32 * R, Vector3((-0.35 + i * 0.35) * R, 1.12 * R, (0.0 + (i % 2) * 0.2) * R), m, 8)
				tuft.rotation = Vector3(0.2 * (i % 2 * 2 - 1), 0, 0.9 - i * 0.55)
		"buzz":
			T.sphere(head, R * 1.025, Vector3(0, 0.1 * R, 0.1 * R), m, Vector3(fw, 0.96, 1.0))
		"spiky":
			T.sphere(head, R * 1.05, Vector3(0, 0.16 * R, 0.12 * R), m, Vector3(fw, 0.92, 1.0))
			for i in 9:
				var a := TAU * i / 9.0
				var dir := Vector3(sin(a) * 0.6, 0.85, cos(a) * 0.5 + 0.1).normalized()
				var spike := T.cylinder(head, 0.0, 0.2 * R, 0.55 * R, dir * R * 1.02 + Vector3(0, 0.1 * R, 0.05 * R), m, 8)
				spike.look_at_from_position(spike.position, spike.position + dir, Vector3.UP)
				spike.rotate_object_local(Vector3.RIGHT, PI / 2.0)
		"long":
			T.sphere(head, R * 1.09, Vector3(0, 0.18 * R, 0.16 * R), m, Vector3(fw, 0.95, 1.05))
			T.box(head, Vector3(2.0 * R * fw, 1.5 * R, 0.5 * R), Vector3(0, -0.45 * R, 0.78 * R), m)
			for sx in [-1.0, 1.0]:
				T.capsule(head, 0.16 * R, 1.3 * R, Vector3(sx * 0.95 * R * fw, -0.35 * R, 0.1 * R), m)
		"curly":
			T.sphere(head, R * 1.05, Vector3(0, 0.15 * R, 0.14 * R), m, Vector3(fw, 0.9, 1.0))
			for i in 14:
				var a := TAU * i / 14.0
				var up := 0.5 + 0.5 * sin(i * 2.3)
				var p := Vector3(sin(a) * 0.85 * R * fw, 0.35 * R + up * 0.55 * R, cos(a) * 0.8 * R + 0.1 * R)
				T.sphere(head, 0.3 * R, p, m)
		_:
			pass


func _beard(R: float, fw: float, hair_m: Material, skin: Color) -> void:
	var style := str(cfg.beard)
	if style == "stubble":
		var st := T.mat(skin.lerp(cfg.hair_color, 0.45), false, 0.9)
		T.sphere(head, R * 1.02, Vector3(0, -0.3 * R, -0.04 * R), st, Vector3(fw, 0.78, 1.0))
	elif style == "full":
		# jaw + chin, set back so the mouth stays visible, plus sideburns
		T.sphere(head, R * 0.98, Vector3(0, -0.66 * R, 0.0), hair_m, Vector3(0.93 * fw, 0.52, 0.9))
		T.sphere(head, 0.2 * R, Vector3(0, -0.84 * R, -0.68 * R), hair_m, Vector3(1.4, 0.9, 0.8))
		for sx in [-1.0, 1.0]:
			T.sphere(head, 0.3 * R, Vector3(sx * 0.82 * R * fw, -0.28 * R, -0.18 * R), hair_m, Vector3(0.6, 1.5, 1.0))
	elif style == "goatee":
		T.sphere(head, R * 0.22, Vector3(0, -0.82 * R, -0.6 * R), hair_m, Vector3(1.0, 1.3, 0.8))
	if cfg.moustache:
		for sx in [-1.0, 1.0]:
			var mo := T.capsule(head, 0.07 * R, 0.4 * R, Vector3(sx * 0.17 * R, -0.24 * R, -0.95 * R), hair_m)
			mo.rotation.z = PI / 2.0 + sx * 0.18


func _glasses(R: float, fw: float) -> void:
	var gm := T.mat(cfg.glasses_color, false, 0.4)
	var lens := StandardMaterial3D.new()
	lens.albedo_color = Color(0.7, 0.85, 1.0, 0.18)
	lens.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for sx in [-1.0, 1.0]:
		var pos := Vector3(sx * 0.34 * R * fw, 0.1 * R, -0.96 * R)
		var ring := T.torus(head, 0.2 * R, 0.27 * R, pos, gm)
		ring.rotation.x = PI / 2.0
		var disc := T.cylinder(head, 0.21 * R, 0.21 * R, 0.01 * R, pos, lens)
		disc.rotation.x = PI / 2.0
		T.box(head, Vector3(0.05 * R, 0.05 * R, 0.9 * R), Vector3(sx * 0.94 * R * fw, 0.12 * R, -0.5 * R), gm)
	T.box(head, Vector3(0.2 * R, 0.05 * R, 0.05 * R), Vector3(0, 0.15 * R, -0.99 * R), gm)


func _accessory(R: float, fw: float) -> void:
	var m := T.mat(cfg.accessory_color)
	match str(cfg.accessory):
		"cap":
			var dome := T.sphere(head, R * 1.1, Vector3(0, 0.28 * R, 0.08 * R), m, Vector3(fw, 0.8, 1.0))
			dome.name = "CapDome"
			T.box(head, Vector3(1.3 * R, 0.09 * R, 0.8 * R), Vector3(0, 0.38 * R, -0.95 * R), m)
		"headband":
			var band := T.torus(head, 0.97 * R, 1.08 * R, Vector3(0, 0.45 * R, 0.0), m)
			band.scale = Vector3(fw, 1.0, 1.0)


# ---------------------------------------------------------------- animation

func animate(state: String, speed: float, delta: float) -> void:
	if body == null:
		return
	blink_t -= delta
	var blink := 1.0
	if blink_t < 0.12:
		blink = 0.12
		if blink_t < 0.0:
			blink_t = randf_range(1.8, 4.0)
	eye_l.scale.y = lerpf(eye_l.scale.y, blink, 0.6)
	eye_r.scale.y = lerpf(eye_r.scale.y, blink, 0.6)

	var k := minf(1.0, delta * 14.0)
	var t_body_x := 0.0
	var t_body_y := 0.0
	var arm_l_x := 0.0
	var arm_r_x := 0.0
	var arm_l_z := 0.0
	var arm_r_z := 0.0
	var leg_l_x := 0.0
	var leg_r_x := 0.0
	var head_x := 0.0
	var t := Time.get_ticks_msec() / 1000.0

	match state:
		"run":
			phase += delta * (7.0 + speed * 0.9)
			var s := sin(phase)
			leg_l_x = s * 1.0
			leg_r_x = -s * 1.0
			arm_l_x = -s * 1.1
			arm_r_x = s * 1.1
			t_body_x = -0.18
			t_body_y = absf(cos(phase)) * 0.07
			head_x = 0.1
		"jump":
			arm_l_x = 2.5
			arm_r_x = 2.5
			arm_l_z = -0.25
			arm_r_z = 0.25
			leg_l_x = 0.5
			leg_r_x = -0.5
			t_body_x = -0.08
		"fall":
			arm_l_z = -1.3
			arm_r_z = 1.3
			leg_l_x = 0.35
			leg_r_x = -0.35
			t_body_y = 0.0
		"spin":
			arm_l_z = -1.5
			arm_r_z = 1.5
			leg_l_x = 0.2
			leg_r_x = -0.2
			t_body_x = -0.1
		"slide":
			t_body_x = 1.15
			arm_l_x = 1.5
			arm_r_x = 1.5
			leg_l_x = -1.4
			leg_r_x = -1.2
			t_body_y = -0.28
		"slam":
			arm_l_x = 3.0
			arm_r_x = 3.0
			leg_l_x = -0.8
			leg_r_x = -0.8
			t_body_x = -0.25
		"win":
			arm_l_x = 3.0 + sin(t * 12.0) * 0.4
			arm_r_x = 3.0 - sin(t * 12.0) * 0.4
			arm_l_z = -0.4
			arm_r_z = 0.4
			t_body_y = absf(sin(t * 7.0)) * 0.18
			leg_l_x = sin(t * 7.0) * 0.3
			leg_r_x = -sin(t * 7.0) * 0.3
		"dead":
			arm_l_x = sin(t * 25.0) * 1.5 + 2.5
			arm_r_x = -sin(t * 25.0) * 1.5 + 2.5
			leg_l_x = sin(t * 21.0)
			leg_r_x = -sin(t * 21.0)
		_:  # idle
			var br := sin(t * 2.4)
			t_body_y = br * 0.012
			arm_l_z = -0.1 - br * 0.03
			arm_r_z = 0.1 + br * 0.03
			head_x = sin(t * 1.3) * 0.05
			arm_l_x = sin(t * 1.7) * 0.06
			arm_r_x = -sin(t * 1.7) * 0.06

	body.rotation.x = lerpf(body.rotation.x, t_body_x, k)
	body.position.y = lerpf(body.position.y, t_body_y, k)
	arm_l.rotation.x = lerpf(arm_l.rotation.x, arm_l_x, k)
	arm_r.rotation.x = lerpf(arm_r.rotation.x, arm_r_x, k)
	arm_l.rotation.z = lerpf(arm_l.rotation.z, arm_l_z, k)
	arm_r.rotation.z = lerpf(arm_r.rotation.z, arm_r_z, k)
	leg_l.rotation.x = lerpf(leg_l.rotation.x, leg_l_x, k)
	leg_r.rotation.x = lerpf(leg_r.rotation.x, leg_r_x, k)
	head.rotation.x = lerpf(head.rotation.x, head_x, k)

	# squash & stretch (decays back to 1)
	squash = move_toward(squash, 0.0, delta * 3.0)
	body.scale = Vector3(1.0 - squash * 0.5, 1.0 + squash, 1.0 - squash * 0.5)

	# invulnerability flicker
	visible = true if flash <= 0.0 else (int(t * 18.0) % 2 == 0)
	flash = maxf(0.0, flash - delta)


func pop(amount: float) -> void:
	squash = clampf(amount, -0.35, 0.35)
