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
