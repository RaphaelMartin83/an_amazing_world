extends StaticBody3D
# Crates. kinds: basic, bounce, life, mask, checkpoint, iron (unbreakable), boom (fuse, explodes)

const T = preload("res://scripts/toon.gd")

var kind := "basic"
var bounces_left := 5
var fuse := -1.0
var broken := false
var counts_for_total := true
var visual: Node3D
var body_mat: StandardMaterial3D
var fuse_label: Label3D
var _last_tick := 99

const Explosion = preload("res://scripts/explosion.gd")


static var _tex := {}

const STYLE := {
	"basic": {"base": Color(0.80, 0.55, 0.28), "label": "", "label_color": Color.WHITE},
	"bounce": {"base": Color(0.80, 0.55, 0.28), "label": "^", "label_color": Color(1.0, 0.55, 0.1)},
	"life": {"base": Color(0.55, 0.78, 0.35), "label": "", "label_color": Color.WHITE},
	"mask": {"base": Color(0.62, 0.45, 0.80), "label": "M", "label_color": Color(1, 0.95, 0.5)},
	"checkpoint": {"base": Color(0.80, 0.55, 0.28), "label": "C", "label_color": Color(0.35, 1.0, 0.45)},
	"iron": {"base": Color(0.55, 0.58, 0.64), "label": "", "label_color": Color.WHITE},
	"boom": {"base": Color(0.82, 0.30, 0.25), "label": "BOOM", "label_color": Color(1, 0.95, 0.4)},
}


func setup(k: String) -> void:
	kind = k
	counts_for_total = kind != "iron" and kind != "checkpoint"
	collision_layer = 1
	collision_mask = 0
	add_to_group("crate")
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE
	cs.shape = shape
	add_child(cs)
	visual = Node3D.new()
	add_child(visual)
	var st: Dictionary = STYLE[kind]
	body_mat = T.mat(st.base, true, 0.8, _plank_tex(kind, st.base), 0.025)
	T.box(visual, Vector3.ONE * 0.98, Vector3.ZERO, body_mat)
	if kind == "life" and Game.face_texture:
		for face in _faces():
			var sp := Sprite3D.new()
			sp.texture = Game.face_texture
			sp.pixel_size = 0.0065
			sp.shaded = false
			sp.double_sided = false
			sp.transform = face
			visual.add_child(sp)
	elif st.label != "":
		for face in _faces():
			var lab := Label3D.new()
			lab.text = st.label
			lab.font_size = 150 if st.label.length() == 1 else 64
			lab.pixel_size = 0.0055
			lab.outline_size = 22
			lab.modulate = st.label_color
			lab.outline_modulate = Color(0.1, 0.05, 0.05)
			lab.shaded = false
			lab.double_sided = false
			lab.transform = face
			visual.add_child(lab)


# Transforms for the 5 visible faces (4 sides + top), slightly above the surface.
func _faces() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for a in [0.0, PI / 2.0, PI, -PI / 2.0]:
		var b := Basis(Vector3.UP, a)
		out.append(Transform3D(b, b * Vector3(0, 0, 0.495 + 0.01)))
	var top := Basis(Vector3.RIGHT, -PI / 2.0)
	out.append(Transform3D(top, Vector3(0, 0.51, 0)))
	return out


static func _plank_tex(k: String, base: Color) -> ImageTexture:
	if _tex.has(k):
		return _tex[k]
	var n := 96
	var img := Image.create(n, n, true, Image.FORMAT_RGB8)
	var dark := base.darkened(0.38)
	var light := base.lightened(0.12)
	img.fill(base)
	if k == "iron":
		for y in n:
			for x in n:
				var v := 1.0 if (x < 7 or x >= n - 7 or y < 7 or y >= n - 7) else 0.0
				img.set_pixel(x, y, base.darkened(0.25) if v > 0.0 else base.lerp(light, 0.4 * float((x / 6 + y / 6) % 2)))
		for c in [Vector2i(14, 14), Vector2i(n - 14, 14), Vector2i(14, n - 14), Vector2i(n - 14, n - 14)]:
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					if dx * dx + dy * dy <= 9:
						img.set_pixel(c.x + dx, c.y + dy, Color(0.85, 0.88, 0.92))
	else:
		for y in n:
			for x in n:
				var border := x < 9 or x >= n - 9 or y < 9 or y >= n - 9
				var plank := y % 24 < 2 and not border
				var c := base
				if border:
					c = dark
				elif plank:
					c = base.darkened(0.25)
				else:
					c = base.lerp(light, 0.5 * float((y / 24) % 2))
				img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[k] = t
	return t


func hit(player: Node3D, how: String) -> void:
	if broken:
		return
	var stomped := how == "stomp" or how == "slam"
	match kind:
		"iron":
			if stomped and player:
				player.bounce(9.5)
			else:
				Sfx.play("clank")
			_wobble()
		"bounce":
			if stomped and player:
				Game.add_fruit(1)
				bounces_left -= 1
				_wobble()
				if bounces_left <= 0:
					_break(null)
				else:
					player.bounce(14.0)
			else:
				Game.add_fruit(maxi(1, bounces_left))
				_break(null)
		"boom":
			if fuse < 0.0:
				fuse = 3.0
				_last_tick = 4
				_make_fuse_label()
			if stomped and player:
				player.bounce(10.5)
			_wobble()
		_:
			if stomped and player:
				player.bounce(9.0)
			_break(player)


func _make_fuse_label() -> void:
	fuse_label = Label3D.new()
	fuse_label.text = "3"
	fuse_label.font_size = 180
	fuse_label.pixel_size = 0.0085
	fuse_label.outline_size = 30
	fuse_label.outline_modulate = Color(0.1, 0.03, 0.03)
	fuse_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fuse_label.no_depth_test = true
	fuse_label.shaded = false
	fuse_label.position = Vector3(0, 1.25, 0)
	add_child(fuse_label)


func _wobble() -> void:
	var tw := create_tween()
	visual.scale = Vector3(1.18, 0.82, 1.18)
	tw.tween_property(visual, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	if fuse >= 0.0 and not broken:
		fuse -= delta
		var whole := ceili(fuse)
		if whole != _last_tick and fuse > 0.0:
			_last_tick = whole
			Sfx.play("fuse", 1.0 + (3 - whole) * 0.18)
			_wobble()
		var pulse := 0.5 + 0.5 * sin(fuse * (14.0 + (3.0 - fuse) * 10.0))   # blinks faster and faster
		visual.scale = Vector3.ONE * (1.0 + pulse * 0.07)
		body_mat.emission_enabled = true
		body_mat.emission = Color(1.0, 0.15, 0.05)
		body_mat.emission_energy_multiplier = pulse * 2.2
		if fuse_label:
			fuse_label.text = str(maxi(1, ceili(fuse)))
			fuse_label.modulate = Color(1.0, 0.9, 0.3).lerp(Color(1.0, 0.2, 0.1), 1.0 - fuse / 3.0)
		if fuse <= 0.0:
			_explode()


func _break(player: Node3D) -> void:
	if broken:
		return
	broken = true
	Sfx.play("crate")
	match kind:
		"basic":
			Game.add_fruit(1)
		"life":
			Game.add_life()
		"mask":
			Game.set_mask(true)
			Sfx.play("mask")
			Game.message.emit("SHIELD!", 1.2)
		"checkpoint":
			Game.set_checkpoint(global_position - Vector3(0, 0.5, 0))
			Sfx.play("checkpoint")
	if counts_for_total:
		Game.crate_broken()
	_burst(Color(0.8, 0.55, 0.28))
	_drop_stack()
	queue_free()


func _explode() -> void:
	broken = true
	if fuse_label:
		fuse_label.queue_free()
	var blast_center := global_position
	var radius := 3.6
	# the visible explosion (lives on in the level after this crate is gone)
	var fx := Explosion.new()
	fx.radius = radius
	fx.floor_y = blast_center.y - 0.5
	get_parent().add_child(fx)
	fx.global_position = blast_center
	Sfx.play("boom")
	# damage: the hero, neighbouring crates and enemies caught in the blast
	var pl: Node3D = Game.player
	if pl and is_instance_valid(pl):
		var d := pl.global_position - blast_center
		if Vector2(d.x, d.z).length() < radius and absf(d.y) < 3.0:
			pl.hurt()
	Game.hit_area(blast_center, radius - 0.2, "spin", null)
	Game.crate_broken()
	_drop_stack()
	queue_free()


func _burst(color: Color, count := 14, speed := 5.5, glow := false) -> void:
	var p := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * (0.2 if not glow else 0.35)
	p.mesh = mesh
	var m := T.emissive(color, 1.6) if glow else T.mat(color, false, 0.8)
	p.material_override = m
	p.amount = count
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.9
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -18, 0)
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.emitting = true
	var parent := get_parent()
	parent.add_child(p)
	p.global_position = global_position
	get_tree().create_timer(1.6).timeout.connect(p.queue_free)


# Crates stacked on top fall down by one when this one goes away.
func _drop_stack() -> void:
	for c in get_tree().get_nodes_in_group("crate"):
		if c == self or not is_instance_valid(c) or c.broken:
			continue
		var d: Vector3 = c.global_position - global_position
		if absf(d.x) < 0.3 and absf(d.z) < 0.3 and d.y > 0.4 and d.y < 1.2:
			var tw: Tween = c.create_tween()
			tw.tween_property(c, "global_position:y", c.global_position.y - 1.0, 0.18).set_ease(Tween.EASE_IN)
