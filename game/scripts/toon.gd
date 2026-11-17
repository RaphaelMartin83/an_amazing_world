extends RefCounted
# Shared helpers for the cartoon look: outlined toon materials, mesh shortcuts, procedural textures.

static var _tex_cache := {}
static var _outline_cache := {}


static func outline_mat(width := 0.035) -> StandardMaterial3D:
	if _outline_cache.has(width):
		return _outline_cache[width]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.07, 0.04, 0.08)
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	m.grow = true
	m.grow_amount = width
	_outline_cache[width] = m
	return m


static func mat(color: Color, outline := true, rough := 0.65, tex: Texture2D = null, outline_w := 0.035) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.5
	if tex:
		m.albedo_texture = tex
	if outline:
		m.next_pass = outline_mat(outline_w)
	return m


static func emissive(color: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func world_tex_mat(tex: Texture2D, tint := Color.WHITE, scale := 0.2) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
	m.roughness = 0.9
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m


static func _place(parent: Node, mi: MeshInstance3D, pos: Vector3, m: Material) -> MeshInstance3D:
	mi.material_override = m
	mi.position = pos
	if parent:
		parent.add_child(mi)
	return mi


static func box(parent: Node, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return _place(parent, mi, pos, m)


static func sphere(parent: Node, radius: float, pos: Vector3, m: Material, squash := Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 32
	mesh.rings = 16
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.scale = squash
	return _place(parent, mi, pos, m)


static func capsule(parent: Node, radius: float, height: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return _place(parent, mi, pos, m)


static func cylinder(parent: Node, r_top: float, r_bottom: float, height: float, pos: Vector3, m: Material, segs := 24) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_bottom
	mesh.height = height
	mesh.radial_segments = segs
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return _place(parent, mi, pos, m)


static func torus(parent: Node, inner: float, outer: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 12
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return _place(parent, mi, pos, m)


# A pointed roof (cone) sitting at height y on a parent node.
static func cone_roof(parent: Node, r: float, y: float) -> MeshInstance3D:
	return cylinder(parent, 0.0, r * 0.95, r * 1.2, Vector3(0, y + r * 0.6, 0), mat(Color(0.8, 0.25, 0.18), true, 0.6, null, 0.05), 16)


# Tileable brick wall texture (8 rows x 4 bricks per tile), cached by key.
static func brick_tex(key: String, a: Color, b: Color, mortar: Color, size := 128) -> ImageTexture:
	if _tex_cache.has(key):
		return _tex_cache[key]
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	var rows := 8
	var cols := 4
	var bh := size / rows
	var bw := size / cols
	var n := FastNoiseLite.new()
	n.frequency = 0.12
	n.seed = 11
	for y in size:
		var row: int = y / bh
		var off: int = (bw / 2) if row % 2 == 1 else 0
		for x in size:
			var xx: int = (x + off) % size
			var col: int = xx / bw
			var lx: int = xx % bw
			var ly: int = y % bh
			var c: Color
			if lx < 2 or ly < 2:
				c = mortar
			else:
				var h := float((row * 7 + col * 13 + row * col * 5) % 10) / 10.0
				c = a.lerp(b, h * 0.7 + (n.get_noise_2d(x, y) * 0.5 + 0.5) * 0.3)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache[key] = t
	return t


# Wooden planks (horizontal boards with grain), cached by key.
static func plank_tex(key: String, a: Color, b: Color, size := 128) -> ImageTexture:
	if _tex_cache.has(key):
		return _tex_cache[key]
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	var n := FastNoiseLite.new()
	n.frequency = 0.05
	n.seed = 17
	var rows := 8
	var ph := size / rows
	for y in size:
		var row: int = y / ph
		var tone := float((row * 37) % 10) / 10.0
		for x in size:
			var c := a.lerp(b, tone * 0.6 + (n.get_noise_2d(x * 0.35, y * 4.0) * 0.5 + 0.5) * 0.4)
			if y % ph < 2:
				c = a.darkened(0.55)
			elif (x + row * 41) % size < 2:
				c = c.darkened(0.3)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache[key] = t
	return t


# Building facade: a grid of windows, some of them lit (also drives an emission map so they glow at dusk).
static func window_mat(key: String, wall_a: Color, wall_b: Color, lit_a: Color, lit_b: Color, size := 128) -> StandardMaterial3D:
	var cell := 16
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	var em := Image.create(size, size, true, Image.FORMAT_RGB8)
	var n := FastNoiseLite.new()
	n.frequency = 0.08
	n.seed = 23
	for y in size:
		for x in size:
			var cx: int = x / cell
			var cy: int = y / cell
			var lx := x % cell
			var ly := y % cell
			var wall := wall_a.lerp(wall_b, n.get_noise_2d(x, y) * 0.5 + 0.5)
			var c := wall
			var e := Color.BLACK
			if lx >= 3 and lx < cell - 3 and ly >= 3 and ly < cell - 3:
				var h := float((cx * 73 + cy * 151 + cx * cy * 31) % 100) / 100.0
				if h > 0.52:
					var lit := lit_a.lerp(lit_b, float((cx * 11 + cy * 7) % 10) / 10.0)
					c = lit
					e = lit
				else:
					c = Color(0.08, 0.1, 0.17)
			img.set_pixel(x, y, c)
			em.set_pixel(x, y, e)
	img.generate_mipmaps()
	em.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.emission_enabled = true
	m.emission_texture = ImageTexture.create_from_image(em)
	m.emission_energy_multiplier = 1.6
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.08
	m.roughness = 0.85
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m


# Hazard chevrons (yellow on dark grey) for conveyor belts; arrows point towards the top of the image.
static func chevron_tex(size := 64) -> ImageTexture:
	if _tex_cache.has("chevron"):
		return _tex_cache["chevron"]
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var d := (y + absi(x - size / 2)) % size
			img.set_pixel(x, y, Color(1.0, 0.8, 0.1) if d < size * 0.3 else Color(0.2, 0.21, 0.24))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache["chevron"] = t
	return t


# Seamless two-colour noise texture, cached by key.
static func noise_tex(key: String, a: Color, b: Color, freq := 0.06, size := 128, seed_ := 1) -> ImageTexture:
	if _tex_cache.has(key):
		return _tex_cache[key]
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.seed = seed_
	var g: Image = n.get_seamless_image(size, size)
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			img.set_pixel(x, y, a.lerp(b, g.get_pixel(x, y).r))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache[key] = t
	return t
