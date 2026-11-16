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

var root: Node3D
var theme: Dictionary
var rng := RandomNumberGenerator.new()
var info := {
	"start": Vector3(0, 0.1, 0),
	"camera_offset": Vector3(0, 4.6, 8.6),
	"camera_look": Vector3(0, 1.3, -3.0),
	"kill_y": -12.0,
	"boulder": null,
	"goal": null,
}
var _grass: StandardMaterial3D
var _path: StandardMaterial3D
var _dirt: StandardMaterial3D
var _grass_side: StandardMaterial3D


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


# ------------------------------------------------------------------ terrain

# A solid block whose top surface is at top_y. Spans z_a..z_b (either order), centred on x.
func ground(x: float, top_y: float, z_a: float, z_b: float, width: float, depth := 8.0) -> StaticBody3D:
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
	T.box(body, Vector3(width, depth - 0.1, length), Vector3(0, -0.05, 0), _dirt)
	T.box(body, Vector3(width + 0.4, 0.34, length + 0.4), Vector3(0, depth * 0.5 - 0.17, 0), _path)
	# lip stones along the long edges for a chunky look
	var lip := T.mat(theme.lip, true, 0.9)
	for sx in [-1.0, 1.0]:
		T.box(body, Vector3(0.16, 0.5, length), Vector3(sx * (width * 0.5 + 0.2), depth * 0.5 - 0.4, 0), lip)
	root.add_child(body)
	return body


# Decorative terrain: no collision.
func scenery_block(center: Vector3, size: Vector3, grass := true) -> void:
	var n := Node3D.new()
	n.position = center
	T.box(n, size - Vector3(0, 0.1, 0), Vector3(0, -0.05, 0), _dirt)
	if grass:
		T.box(n, Vector3(size.x + 0.3, 0.4, size.z + 0.3), Vector3(0, size.y * 0.5 - 0.2, 0), _grass)
	root.add_child(n)


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


func mover(pos: Vector3, size: Vector3, axis: Vector3, dist: float, speed: float, phase := 0.0) -> Node3D:
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
	T.box(m, size, Vector3.ZERO, _dirt)
	T.box(m, Vector3(size.x + 0.2, 0.2, size.z + 0.2), Vector3(0, size.y * 0.5 - 0.1, 0), T.mat(theme.lip, true, 0.7))
	T.box(m, Vector3(size.x - 0.4, 0.05, size.z - 0.4), Vector3(0, size.y * 0.5 + 0.02, 0), _path)
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
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rng.randf() * TAU
	var trunk_m := T.mat(Color(0.45, 0.28, 0.16), false, 0.9)
	var leaf_a := T.mat(theme.leaf_a, false, 0.7)
	var leaf_b := T.mat(theme.leaf_b, false, 0.7)
	var h := rng.randf_range(4.0, 7.0) * scale
	if rng.randf() < 0.5:
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


func scatter_trees(z_a: float, z_b: float, y: float, x_min: float, x_max: float, count: int) -> void:
	for i in count:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
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
