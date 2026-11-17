extends RefCounted
# Helpers for assembling levels from code: terrain blocks, crates, fruit, enemies, hazards, scenery.

const T = preload("res://scripts/toon.gd")
const Crate = preload("res://scripts/crate.gd")
const Fruit = preload("res://scripts/fruit.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Mover = preload("res://scripts/mover.gd")
const Spinner = preload("res://scripts/spinner.gd")
const Goal = preload("res://scripts/goal.gd")
const Boulder = preload("res://scripts/boulder.gd")
const Crumble = preload("res://scripts/crumble.gd")
const Gem = preload("res://scripts/gem.gd")
const Conveyor = preload("res://scripts/conveyor.gd")
const Wave = preload("res://scripts/wave.gd")
const Boss = preload("res://scripts/boss.gd")
const CigarBoss = preload("res://scripts/cigar_boss.gd")

var root: Node3D
var theme: Dictionary
var rng := RandomNumberGenerator.new()
var info := {
	"start": Vector3(0, 0.1, 0),
	"camera_offset": Vector3(0, 4.6, 8.6),
	"camera_look": Vector3(0, 1.3, -3.0),
	"kill_y": -12.0,
	"boulder": null,
	"boss": null,
	"goal": null,
}
var _grass: StandardMaterial3D
var _path: StandardMaterial3D
var _dirt: StandardMaterial3D
var _grass_side: StandardMaterial3D
var _wood: StandardMaterial3D
var _ice: StandardMaterial3D
var _snow: StandardMaterial3D
var _carpet: StandardMaterial3D


func _init(r: Node3D, th: Dictionary) -> void:
	root = r
	theme = th
	rng.seed = 1234
	var gt := T.noise_tex("top_" + str(theme.name), theme.top_a, theme.top_b, 0.07, 128, 3)
	var dt := T.noise_tex("dirt_" + str(theme.name), theme.dirt_a, theme.dirt_b, 0.1, 128, 9)
	var pt := T.noise_tex("path_" + str(theme.name), theme.path_a, theme.path_b, 0.11, 128, 5)
	_path = T.world_tex_mat(pt, Color.WHITE, 0.22)
	_grass = T.world_tex_mat(gt, Color.WHITE, 0.18)
	_dirt = T.world_tex_mat(dt, Color.WHITE, 0.14)
	if theme.get("facade", false):
		_dirt = T.window_mat("facade_" + str(theme.name), theme.dirt_a, theme.dirt_b, Color(1.0, 0.85, 0.5), Color(0.6, 0.9, 1.0))
	_wood = T.world_tex_mat(T.plank_tex("planks", Color(0.50, 0.32, 0.18), Color(0.72, 0.5, 0.3)), Color.WHITE, 0.3)
	_ice = T.world_tex_mat(T.noise_tex("ice", Color(0.55, 0.80, 0.95), Color(0.86, 0.96, 1.0), 0.05, 128, 21), Color.WHITE, 0.15)
	_ice.roughness = 0.12
	_ice.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	_snow = T.world_tex_mat(T.noise_tex("snow", Color(0.84, 0.91, 0.98), Color(1.0, 1.0, 1.0), 0.04, 128, 8), Color.WHITE, 0.2)
	_carpet = T.world_tex_mat(T.noise_tex("carpet", Color(0.42, 0.06, 0.09), Color(0.62, 0.14, 0.14), 0.15, 128, 41), Color.WHITE, 0.3)
	if theme.get("planks", false):
		_dirt = T.world_tex_mat(T.plank_tex("lounge_wall", theme.dirt_a, theme.dirt_b), Color.WHITE, 0.25)
	if theme.get("brick", false):
		_dirt = T.world_tex_mat(T.brick_tex("brick_" + str(theme.name), theme.dirt_a, theme.dirt_b, theme.dirt_a.darkened(0.55)), Color.WHITE, 0.25)


# ------------------------------------------------------------------ terrain

# A solid block whose top surface is at top_y. Spans z_a..z_b (either order), centred on x.
func _top(style: String) -> Material:
	match style:
		"wood":
			return _wood
		"ice":
			return _ice
		"snow":
			return _snow
		"carpet":
			return _carpet
	return _path


func _side(style: String) -> Material:
	match style:
		"wood":
			return _wood
		"ice":
			return _ice
	return _dirt


# style: "path" (theme default) | "wood" | "ice" (slippery) | "snow"
func ground(x: float, top_y: float, z_a: float, z_b: float, width: float, depth := 8.0, style := "path") -> StaticBody3D:
	var zc := (z_a + z_b) * 0.5
	var length := absf(z_a - z_b)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3(x, top_y - depth * 0.5, zc)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, depth, length)
	cs.shape = shape
	body.add_child(cs)
	T.box(body, Vector3(width, depth - 0.1, length), Vector3(0, -0.05, 0), _side(style))
	T.box(body, Vector3(width + 0.4, 0.34, length + 0.4), Vector3(0, depth * 0.5 - 0.17, 0), _top(style))
	if style == "ice":
		body.add_to_group("ice")
	# lip stones along the long edges for a chunky look
	var lip := T.mat(theme.lip, true, 0.9)
	for sx in [-1.0, 1.0]:
		T.box(body, Vector3(0.16, 0.5, length), Vector3(sx * (width * 0.5 + 0.2), depth * 0.5 - 0.4, 0), lip)
	root.add_child(body)
	return body


# Decorative terrain: no collision.
func scenery_block(center: Vector3, size: Vector3, grass := true) -> Node3D:
	var n := Node3D.new()
	n.position = center
	T.box(n, size - Vector3(0, 0.1, 0), Vector3(0, -0.05, 0), _dirt)
	if grass:
		T.box(n, Vector3(size.x + 0.3, 0.4, size.z + 0.3), Vector3(0, size.y * 0.5 - 0.2, 0), _grass)
	root.add_child(n)
	return n


func water(y: float, center_z: float, length: float) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(400, length + 200)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = theme.water
	m.roughness = 0.08
	m.metallic = 0.2
	m.emission_enabled = true
	m.emission = theme.water.darkened(0.4)
	m.emission_energy_multiplier = 0.6
	mi.material_override = m
	mi.position = Vector3(0, y, center_z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


# ------------------------------------------------------------------ gameplay objects

func crate(kind: String, pos: Vector3) -> Node3D:
	var c := Crate.new()
	c.position = pos + Vector3(0, 0.5, 0)
	root.add_child(c)
	c.setup(kind)
	if kind == "bounce":
		# the reward for bouncing high on it (hold jump when landing): a gem floating above
		var g := Gem.new()
		g.position = pos + Vector3(0, 5.2, 0)
		root.add_child(g)
	return c


func stack(kind: String, pos: Vector3, n: int) -> void:
	for i in n:
		crate(kind, pos + Vector3(0, i, 0))


func fruit(pos: Vector3) -> void:
	var f := Fruit.new()
	f.position = pos
	root.add_child(f)


func fruit_line(a: Vector3, b: Vector3, n: int) -> void:
	for i in n:
		fruit(a.lerp(b, 0.0 if n == 1 else float(i) / (n - 1)))


func fruit_arc(a: Vector3, b: Vector3, n: int, height: float) -> void:
	for i in n:
		var u := 0.0 if n == 1 else float(i) / (n - 1)
		var p := a.lerp(b, u)
		p.y += sin(u * PI) * height
		fruit(p)


func enemy(kind: String, pos: Vector3, axis := Vector3.RIGHT, dist := 3.0, speed := 1.6, phase := 0.0) -> Node3D:
	var e := Enemy.new()
	e.setup(kind, axis, dist, speed)
	e.position = pos
	root.add_child(e)
	e.t = phase
	return e


func mover(pos: Vector3, size: Vector3, axis: Vector3, dist: float, speed: float, phase := 0.0, style := "path") -> Node3D:
	var m := Mover.new()
	m.axis = axis
	m.dist = dist
	m.speed = speed
	m.phase = phase
	m.position = pos
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	m.add_child(cs)
	T.box(m, size, Vector3.ZERO, _side(style))
	T.box(m, Vector3(size.x + 0.2, 0.2, size.z + 0.2), Vector3(0, size.y * 0.5 - 0.1, 0), T.mat(theme.lip, true, 0.7))
	T.box(m, Vector3(size.x - 0.4, 0.05, size.z - 0.4), Vector3(0, size.y * 0.5 + 0.02, 0), _top(style))
	if style == "ice":
		m.add_to_group("ice")
	root.add_child(m)
	return m


func spinner(pos: Vector3, length: float, speed: float) -> void:
	var s := Spinner.new()
	s.length = length
	s.speed = speed
	s.position = pos
	root.add_child(s)


func rock(pos: Vector3, size: Vector3) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	b.position = pos + Vector3(0, size.y * 0.5, 0)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	b.add_child(cs)
	var tex := T.noise_tex("stone", Color(0.5, 0.48, 0.45), Color(0.78, 0.75, 0.7), 0.12, 128, 4)
	T.box(b, size, Vector3.ZERO, T.mat(Color.WHITE, true, 0.9, tex, 0.04))
	root.add_child(b)


func goal(pos: Vector3) -> void:
	var g := Goal.new()
	g.position = pos
	root.add_child(g)
	info.goal = g


func boulder(pos: Vector3, speed: float) -> Node3D:
	var b := Boulder.new()
	b.position = pos
	b.speed = speed
	root.add_child(b)
	info.boulder = b
	return b


# ------------------------------------------------------------------ scenery

func tree(pos: Vector3, scale := 1.0) -> void:
	if theme.get("pines", false):
		pine(pos, scale)
		return
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rng.randf() * TAU
	var trunk_m := T.mat(Color(0.45, 0.28, 0.16), false, 0.9)
	var leaf_a := T.mat(theme.leaf_a, false, 0.7)
	var leaf_b := T.mat(theme.leaf_b, false, 0.7)
	var h := rng.randf_range(4.0, 7.0) * scale
	if theme.get("palms_only", false) or rng.randf() < 0.5:
		# palm
		var tr := T.cylinder(n, 0.16 * scale, 0.28 * scale, h, Vector3(0, h * 0.5, 0), trunk_m, 8)
		tr.rotation.z = rng.randf_range(-0.15, 0.15)
		for i in 7:
			var a := TAU * i / 7.0
			var leaf := T.sphere(n, 1.0, Vector3(cos(a) * 1.5 * scale, h + 0.2, sin(a) * 1.5 * scale), leaf_a if i % 2 == 0 else leaf_b, Vector3(2.2 * scale, 0.14 * scale, 0.55 * scale))
			leaf.rotation = Vector3(0, -a, -0.35)
	else:
		T.cylinder(n, 0.3 * scale, 0.5 * scale, h, Vector3(0, h * 0.5, 0), trunk_m, 8)
		T.sphere(n, 2.0 * scale, Vector3(0, h + 0.8 * scale, 0), leaf_a)
		T.sphere(n, 1.4 * scale, Vector3(1.2 * scale, h + 0.1, 0.4 * scale), leaf_b)
		T.sphere(n, 1.5 * scale, Vector3(-1.1 * scale, h + 0.3, -0.5 * scale), leaf_b)
	root.add_child(n)


func scatter_trees(z_a: float, z_b: float, y: float, x_min: float, x_max: float, count: int, only_side := 0.0) -> void:
	for i in count:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		if only_side != 0.0:
			side = only_side
		var p := Vector3(side * rng.randf_range(x_min, x_max), y, rng.randf_range(minf(z_a, z_b), maxf(z_a, z_b)))
		tree(p, rng.randf_range(0.8, 1.5))


func mountains(z_center: float) -> void:
	for i in 16:
		var side := -1.0 if i % 2 == 0 else 1.0
		var m := T.mat(theme.mountain.lerp(theme.fog, rng.randf_range(0.2, 0.6)), false, 1.0)
		var h := rng.randf_range(40.0, 90.0)
		T.cylinder(root, 0.0, rng.randf_range(35.0, 60.0), h, Vector3(side * rng.randf_range(110.0, 190.0), h * 0.5 - 20.0, z_center + rng.randf_range(-150.0, 150.0)), m, 7)


func pillar(pos: Vector3, h: float, broken := false) -> void:
	var stone := T.mat(theme.pillar, true, 0.9, T.noise_tex("stone", Color(0.5, 0.48, 0.45), Color(0.78, 0.75, 0.7), 0.12, 128, 4), 0.05)
	var n := Node3D.new()
	n.position = pos
	T.cylinder(n, 1.1, 1.3, 0.6, Vector3(0, 0.3, 0), stone, 12)
	T.cylinder(n, 0.85, 0.95, h, Vector3(0, h * 0.5 + 0.3, 0), stone, 12)
	if not broken:
		T.box(n, Vector3(2.6, 0.6, 2.6), Vector3(0, h + 0.6, 0), stone)
	else:
		var chunk := T.box(n, Vector3(1.0, 0.7, 0.9), Vector3(1.4, 0.35, 0.8), stone)
		chunk.rotation = Vector3(0.2, 0.6, 0.3)
	root.add_child(n)


func torch(pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	T.cylinder(n, 0.12, 0.18, 1.6, Vector3(0, 0.8, 0), T.mat(Color(0.35, 0.25, 0.2), true))
	T.sphere(n, 0.3, Vector3(0, 1.8, 0), T.emissive(Color(1.0, 0.55, 0.15), 2.5))
	T.box(n, Vector3(0.5, 0.15, 0.5), Vector3(0, 0.0, 0.0), T.mat(Color(0.4, 0.4, 0.45), true))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.25)
	l.omni_range = 11.0
	l.light_energy = 1.6
	l.position = Vector3(0, 2.0, 0)
	n.add_child(l)
	root.add_child(n)


# ------------------------------------------------------------------ sewer pieces

func crumble(pos: Vector3, size := Vector3(3.6, 0.5, 3.6), style := "metal") -> void:
	var c := Crumble.new()
	c.size = size
	c.style = style
	c.position = pos
	root.add_child(c)


func pipe(pos: Vector3, length: float, radius: float, color: Color) -> void:
	var m := T.mat(color, true, 0.5, null, 0.04)
	var p := T.cylinder(root, radius, radius, length, pos, m, 14)
	p.rotation.x = PI / 2.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var z := pos.z - length * 0.5 + 4.0
	while z < pos.z + length * 0.5:
		var ring := T.cylinder(root, radius * 1.18, radius * 1.18, 0.35, Vector3(pos.x, pos.y, z), m, 14)
		ring.rotation.x = PI / 2.0
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		z += 9.0


func lamp(pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	T.cylinder(n, 0.05, 0.05, 14.0 - pos.y, Vector3(0, (14.0 - pos.y) * 0.5, 0), T.mat(Color(0.2, 0.2, 0.2), false), 6)
	T.sphere(n, 0.32, Vector3.ZERO, T.emissive(Color(1.0, 0.82, 0.45), 3.0))
	T.cylinder(n, 0.1, 0.42, 0.3, Vector3(0, 0.34, 0), T.mat(Color(0.25, 0.25, 0.28), true), 10)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.78, 0.45)
	l.omni_range = 15.0
	l.light_energy = 2.6
	l.position = Vector3(0, -0.4, 0)
	n.add_child(l)
	root.add_child(n)


func sludgefall(pos: Vector3) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.4, 0.75, 0.15, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(0.3, 0.6, 0.1)
	m.emission_energy_multiplier = 0.8
	var f := T.cylinder(root, 0.3, 0.45, 12.0, pos + Vector3(0, -2.0, 0), m, 10)
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	T.cylinder(root, 0.55, 0.55, 0.7, pos + Vector3(0, 4.2, 0), T.mat(Color(0.35, 0.4, 0.4), true), 12)


# Brick tunnel around z_a..z_b: side walls, ceiling, ribs, pipes, lamps, end walls.
func tunnel(z_a: float, z_b: float, pipes := true) -> void:
	var z_lo := minf(z_a, z_b)
	var z_hi := maxf(z_a, z_b)
	var zc := (z_lo + z_hi) * 0.5
	var length := z_hi - z_lo
	for side in [-1.0, 1.0]:
		scenery_block(Vector3(side * 17.0, 4.0, zc), Vector3(12.0, 24.0, length), false)
	var ceil_n := scenery_block(Vector3(0, 18.0, zc), Vector3(46.0, 10.0, length), false)
	for ch in ceil_n.get_children():
		if ch is GeometryInstance3D:
			ch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scenery_block(Vector3(0, 4.0, z_hi + 1.0), Vector3(26.0, 24.0, 2.0), false)
	scenery_block(Vector3(0, 4.0, z_lo - 1.0), Vector3(26.0, 24.0, 2.0), false)
	var rib_m := T.mat(theme.lip.darkened(0.25), false, 0.9)
	var z := z_lo + 6.0
	while z < z_hi:
		T.box(root, Vector3(22.0, 0.9, 1.3), Vector3(0, 12.5, z), rib_m).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for side in [-1.0, 1.0]:
			T.box(root, Vector3(0.9, 14.0, 1.3), Vector3(side * 10.6, 5.0, z), rib_m).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		z += 12.0
	if pipes:
		for side in [-1.0, 1.0]:
			pipe(Vector3(side * 10.1, 2.4, zc), length, 0.6, Color(0.55, 0.3, 0.2))
			pipe(Vector3(side * 10.2, 5.6, zc), length, 0.42, Color(0.28, 0.5, 0.5))
			pipe(Vector3(side * 6.5, 11.9, zc), length, 0.5, Color(0.5, 0.45, 0.3))
	var i := 0
	z = z_lo + 10.0
	while z < z_hi:
		lamp(Vector3(-6.0 if i % 2 == 0 else 6.0, 9.2, z))
		if pipes and i % 3 == 1:
			sludgefall(Vector3(-9.6 if i % 2 == 0 else 9.6, 6.0, z + 6.0))
		z += 15.0
		i += 1


# ------------------------------------------------------------------ gameplay extras

func conveyor(top_y: float, z_a: float, z_b: float, width: float, dir: Vector3, speed := 4.5) -> void:
	var c := Conveyor.new()
	var length := absf(z_a - z_b)
	c.size = Vector3(width, 0.5, length)
	c.dir = dir
	c.speed = speed
	c.position = Vector3(0, top_y - 0.25, (z_a + z_b) * 0.5)
	root.add_child(c)


func wave(z: float, floor_y := 0.0, width := 10.0, phase := 0.0) -> void:
	var w := Wave.new()
	w.width = width
	w.phase = phase
	w.position = Vector3(0, floor_y, z)
	root.add_child(w)


# ------------------------------------------------------------------ city

# Buildings on both sides, at assorted heights, with antennas.
func skyline(z_a: float, z_b: float) -> void:
	var z := minf(z_a, z_b)
	while z < maxf(z_a, z_b):
		for side in [-1.0, 1.0]:
			var w := rng.randf_range(8.0, 16.0)
			var d := rng.randf_range(10.0, 18.0)
			var top := rng.randf_range(-10.0, 36.0)
			var inner := 10.5 + rng.randf_range(0.0, 8.0)
			scenery_block(Vector3(side * (inner + w * 0.5), top - 45.0, z + d * 0.5), Vector3(w, 90.0, d), true)
			if rng.randf() < 0.6:
				var ax: float = side * (inner + w * 0.5)
				T.cylinder(root, 0.12, 0.12, 7.0, Vector3(ax, top + 3.5, z + d * 0.5), T.mat(Color(0.3, 0.3, 0.35), false), 6)
				T.sphere(root, 0.25, Vector3(ax, top + 7.0, z + d * 0.5), T.emissive(Color(1.0, 0.1, 0.1), 3.0))
		z += rng.randf_range(11.0, 18.0)


func neon_sign(pos: Vector3, text: String, color: Color, yaw := 0.0, scale := 1.0) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	var lab := Label3D.new()
	lab.text = text
	lab.font_size = 160
	lab.pixel_size = 0.011 * scale
	lab.modulate = color
	lab.outline_modulate = color.darkened(0.75)
	lab.outline_size = 28
	lab.shaded = false
	lab.double_sided = false
	lab.position = Vector3(0, 0, 0.12)
	n.add_child(lab)
	T.box(n, Vector3((text.length() * 1.15 + 1.0) * scale, 3.0 * scale, 0.3), Vector3(0, 0, 0), T.mat(Color(0.07, 0.06, 0.11), false))
	var l := OmniLight3D.new()
	l.light_color = color
	l.omni_range = 14.0
	l.light_energy = 1.8
	l.position = Vector3(0, 0, 3.0)
	n.add_child(l)
	root.add_child(n)


# ------------------------------------------------------------------ beach

func umbrella(pos: Vector3, color: Color) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.z = 0.12
	T.cylinder(n, 0.05, 0.05, 2.8, Vector3(0, 1.4, 0), T.mat(Color(0.9, 0.9, 0.9), false), 6)
	T.cylinder(n, 0.0, 1.7, 0.8, Vector3(0, 2.8, 0), T.mat(color, true), 12)
	T.cylinder(n, 0.0, 0.9, 0.5, Vector3(0, 3.1, 0), T.mat(Color.WHITE, false), 12)
	root.add_child(n)


# Sandcastle obstacle (solid, jump over it).
func castle(pos: Vector3) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	b.position = pos + Vector3(0, 0.55, 0)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.8, 1.1, 1.6)
	cs.shape = shape
	b.add_child(cs)
	var sand := T.mat(Color(0.92, 0.78, 0.5), true, 0.9, null, 0.035)
	T.box(b, Vector3(2.8, 0.8, 1.6), Vector3(0, -0.15, 0), sand)
	for sx in [-1.0, 1.0]:
		T.cylinder(b, 0.38, 0.45, 1.3, Vector3(sx * 1.25, 0.1, 0), sand, 12)
		T.cylinder(b, 0.0, 0.5, 0.45, Vector3(sx * 1.25, 1.0, 0), T.mat(Color(0.9, 0.35, 0.3), true), 12)
	T.cylinder(b, 0.03, 0.03, 0.9, Vector3(0, 0.7, 0), T.mat(Color.WHITE, false), 6)
	T.box(b, Vector3(0.45, 0.28, 0.03), Vector3(0.24, 1.0, 0), T.mat(Color(0.95, 0.2, 0.25), false))
	root.add_child(b)


func lifeguard_tower(pos: Vector3, yaw := 0.0) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	var wood := T.mat(Color(0.9, 0.9, 0.92), true)
	var red := T.mat(Color(0.9, 0.2, 0.2), true)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			T.cylinder(n, 0.12, 0.12, 3.0, Vector3(sx * 1.0, 1.5, sz * 1.0), wood, 6)
	T.box(n, Vector3(2.6, 0.2, 2.6), Vector3(0, 3.0, 0), red)
	T.box(n, Vector3(2.2, 1.8, 2.2), Vector3(0, 4.0, 0), wood)
	T.box(n, Vector3(3.2, 0.2, 3.2), Vector3(0, 5.0, 0), red)
	root.add_child(n)


# ------------------------------------------------------------------ snow

func pine(pos: Vector3, scale := 1.0) -> void:
	var n := Node3D.new()
	n.position = pos
	var h := rng.randf_range(4.0, 7.5) * scale
	T.cylinder(n, 0.25 * scale, 0.35 * scale, h * 0.4, Vector3(0, h * 0.2, 0), T.mat(Color(0.35, 0.22, 0.14), false), 6)
	var green := T.mat(theme.leaf_a, false, 0.8)
	var white := T.mat(Color(0.96, 0.98, 1.0), false, 0.9)
	for i in 4:
		var y := h * (0.28 + i * 0.2)
		var r := (2.3 - i * 0.5) * scale
		T.cylinder(n, 0.0, r, h * 0.34, Vector3(0, y + h * 0.1, 0), green, 10)
		T.cylinder(n, 0.0, r * 0.82, h * 0.2, Vector3(0, y + h * 0.18, 0), white, 10)
	root.add_child(n)


func snowman(pos: Vector3, yaw := 0.0) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	var snow := T.mat(Color(0.97, 0.98, 1.0), true, 0.8)
	T.sphere(n, 0.9, Vector3(0, 0.9, 0), snow)
	T.sphere(n, 0.65, Vector3(0, 2.1, 0), snow)
	T.sphere(n, 0.45, Vector3(0, 3.0, 0), snow)
	T.cylinder(n, 0.0, 0.09, 0.5, Vector3(0, 3.0, -0.5), T.mat(Color(1.0, 0.5, 0.1), false), 6).rotation.x = -PI / 2.0
	for sx in [-1.0, 1.0]:
		T.sphere(n, 0.06, Vector3(sx * 0.17, 3.12, -0.4), T.mat(Color(0.05, 0.05, 0.08), false))
	T.cylinder(n, 0.3, 0.3, 0.45, Vector3(0, 3.6, 0), T.mat(Color(0.12, 0.12, 0.16), true), 12)
	T.cylinder(n, 0.5, 0.5, 0.06, Vector3(0, 3.38, 0), T.mat(Color(0.12, 0.12, 0.16), true), 12)
	for sx in [-1.0, 1.0]:
		var arm := T.cylinder(n, 0.04, 0.04, 1.3, Vector3(sx * 1.0, 2.2, 0), T.mat(Color(0.35, 0.22, 0.14), false), 6)
		arm.rotation.z = sx * 1.0
	root.add_child(n)


# ------------------------------------------------------------------ boss arena

func boss(pos: Vector3) -> Node3D:
	var b := Boss.new()
	b.position = pos
	root.add_child(b)
	info.boss = b
	return b


# An invisible wall (so nobody wanders out) dressed up as a row of barrels.
func fence(z: float, width := 22.0, kind := "barrels") -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3(0, 4.0, z)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 8.0, 1.2)
	cs.shape = shape
	body.add_child(cs)
	root.add_child(body)
	if kind == "sofas":
		var sx := -width * 0.5 + 2.2
		while sx < width * 0.5 - 1.0:
			sofa(Vector3(sx, 0.0, z), 0.0)
			sx += 4.4
		return
	var x := -width * 0.5 + 0.8
	var i := 0
	while x < width * 0.5:
		barrel(Vector3(x, 0.0, z), 1.0)
		if i % 2 == 0:
			barrel(Vector3(x + 0.8, 1.3, z), 0.9)
		x += 1.7
		i += 1


func barrel(pos: Vector3, scale := 1.0) -> void:
	var n := Node3D.new()
	n.position = pos
	var wood := T.mat(Color(0.6, 0.38, 0.2), true, 0.7, T.plank_tex("planks", Color(0.50, 0.32, 0.18), Color(0.72, 0.5, 0.3)), 0.04)
	var gold := T.mat(Color(0.9, 0.7, 0.2), false, 0.3)
	T.cylinder(n, 0.75 * scale, 0.65 * scale, 0.45 * scale, Vector3(0, 0.22 * scale, 0), wood, 14)
	T.cylinder(n, 0.75 * scale, 0.75 * scale, 0.45 * scale, Vector3(0, 0.67 * scale, 0), wood, 14)
	T.cylinder(n, 0.65 * scale, 0.75 * scale, 0.45 * scale, Vector3(0, 1.12 * scale, 0), wood, 14)
	for hy in [0.3, 1.05]:
		T.cylinder(n, 0.72 * scale, 0.72 * scale, 0.08 * scale, Vector3(0, hy * scale, 0), gold, 14)
	root.add_child(n)


# A big copper brewing vat (decoration).
func vat(pos: Vector3, radius: float, height: float) -> void:
	var n := Node3D.new()
	n.position = pos
	var copper := T.mat(Color(0.78, 0.46, 0.26), true, 0.35, null, 0.05)
	T.cylinder(n, radius, radius, height, Vector3(0, height * 0.5 + 0.8, 0), copper, 20)
	T.sphere(n, radius, Vector3(0, height + 0.8, 0), copper, Vector3(1.0, 0.7, 1.0))
	T.cylinder(n, 0.3, 0.3, 2.5, Vector3(0, height + 2.2, 0), copper, 10)
	for sx in [-1.0, 1.0]:
		T.cylinder(n, 0.2, 0.2, 1.0, Vector3(sx * radius * 0.7, 0.4, 0), T.mat(Color(0.3, 0.3, 0.33), true), 8)
	T.cylinder(n, radius * 1.02, radius * 1.02, 0.25, Vector3(0, height * 0.3 + 0.8, 0), T.mat(Color(0.95, 0.75, 0.2), false), 20)
	var win := T.sphere(n, 0.55, Vector3(0, height * 0.6 + 0.8, -radius + 0.1), T.emissive(Color(1.0, 0.7, 0.25), 2.2), Vector3(1.0, 1.0, 0.4))
	win.name = "Window"
	root.add_child(n)


# ------------------------------------------------------------------ cigar lounge

func cigar_boss(pos: Vector3) -> Node3D:
	var b := CigarBoss.new()
	b.position = pos
	root.add_child(b)
	info.boss = b
	return b


func _leather() -> StandardMaterial3D:
	return T.mat(Color(0.42, 0.18, 0.1), true, 0.45, null, 0.04)


func armchair(pos: Vector3, yaw := 0.0) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	var m := _leather()
	T.box(n, Vector3(1.8, 0.55, 1.6), Vector3(0, 0.45, 0), m)
	T.box(n, Vector3(1.8, 1.4, 0.4), Vector3(0, 1.15, 0.7), m)
	for sx in [-1.0, 1.0]:
		T.box(n, Vector3(0.35, 0.9, 1.6), Vector3(sx * 1.0, 0.7, 0), m)
		T.sphere(n, 0.16, Vector3(sx * 1.0, 0.0, -0.7), T.mat(Color(0.9, 0.7, 0.2), false)).position.y = 0.1
	root.add_child(n)


# A long couch; solid, it makes the south fence of the arena.
func sofa(pos: Vector3, yaw := 0.0) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	var m := _leather()
	T.box(n, Vector3(4.2, 0.6, 1.6), Vector3(0, 0.5, 0), m)
	T.box(n, Vector3(4.2, 1.5, 0.45), Vector3(0, 1.25, 0.65), m)
	for sx in [-1.0, 1.0]:
		T.box(n, Vector3(0.4, 1.0, 1.6), Vector3(sx * 2.0, 0.8, 0), m)
	for i in 5:
		T.sphere(n, 0.1, Vector3(-1.6 + i * 0.8, 1.35, 0.42), T.mat(Color(0.9, 0.7, 0.2), false))
	root.add_child(n)


func ashtray(pos: Vector3, scale := 1.0) -> void:
	var n := Node3D.new()
	n.position = pos
	var glass := T.mat(Color(0.12, 0.13, 0.16), true, 0.15, null, 0.04)
	T.cylinder(n, 1.6 * scale, 1.2 * scale, 0.5 * scale, Vector3(0, 0.25 * scale, 0), glass, 20)
	T.cylinder(n, 1.3 * scale, 1.3 * scale, 0.06 * scale, Vector3(0, 0.5 * scale, 0), T.mat(Color(0.55, 0.55, 0.58), false), 20)
	T.sphere(n, 0.9 * scale, Vector3(0, 0.5 * scale, 0), T.mat(Color(0.72, 0.72, 0.76), true, 0.95), Vector3(1.0, 0.35, 1.0))
	for i in 3:
		var a := i * 2.1
		var butt := T.cylinder(n, 0.12 * scale, 0.12 * scale, 1.3 * scale, Vector3(cos(a) * 0.8 * scale, 0.75 * scale, sin(a) * 0.8 * scale), T.mat(Color(0.45, 0.26, 0.1), false), 8)
		butt.rotation = Vector3(0.0, a, PI / 2.0 - 0.3)
	root.add_child(n)


# A bar along the far wall, shelves of bottles behind it.
func bar(z: float) -> void:
	var wood := T.mat(Color(0.3, 0.15, 0.09), true, 0.5, T.plank_tex("lounge_wall", Color(0.25, 0.12, 0.08), Color(0.4, 0.2, 0.12)), 0.04)
	T.box(root, Vector3(18.0, 1.3, 1.6), Vector3(0, 0.65, z + 0.6), wood)
	T.box(root, Vector3(18.4, 0.15, 2.0), Vector3(0, 1.35, z + 0.6), T.mat(Color(0.55, 0.35, 0.18), true, 0.3))
	for row in 3:
		T.box(root, Vector3(18.0, 0.15, 0.7), Vector3(0, 3.0 + row * 1.6, z - 0.8), wood)
		for i in 22:
			var bx := -8.4 + i * 0.8
			var col: Color = [Color(0.35, 0.18, 0.05), Color(0.15, 0.4, 0.2), Color(0.8, 0.55, 0.15), Color(0.5, 0.1, 0.12)][(i + row) % 4]
			var gm := T.mat(col, false, 0.25)
			T.cylinder(root, 0.17, 0.17, 0.75, Vector3(bx, 3.45 + row * 1.6, z - 0.8), gm, 8)
			T.cylinder(root, 0.06, 0.1, 0.35, Vector3(bx, 3.98 + row * 1.6, z - 0.8), gm, 8)
	var mirror := T.box(root, Vector3(14.0, 4.6, 0.1), Vector3(0, 5.0, z - 1.25), T.emissive(Color(0.35, 0.25, 0.15), 0.5))
	mirror.name = "Mirror"
