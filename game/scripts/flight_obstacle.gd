extends Node3D
# Obstacles for the plane level. Collisions are plain geometry tests (check()), not physics bodies.
#   rock    floating island chunk           balloon  hot-air balloon          storm   dark thundercloud (flashes)
#   tower   windmill: a tower with spinning blades on top                      blimp   cigar-shaped airship lying across the lane
#   gate    a big spinning propeller bar (fly through the open quadrants)      bird    a seagull swaying side to side

const T = preload("res://scripts/toon.gd")

var kind := "rock"
var radius := 3.0
var height := 12.0         # tower: height of the top
var half_len := 7.0        # blimp: half its length (it lies along X)
var bar_len := 9.0         # gate / tower: half length of the spinning bar
var speed := 1.0           # gate / tower spin (rad/s), bird sway (rad/s)
var amp := 6.0             # bird sway amplitude
var phase := 0.0
var origin := Vector3.ZERO
var t := 0.0
var spinner: Node3D
var wings: Array[Node3D] = []
var flash_nodes: Array[Node3D] = []
var storm_light: OmniLight3D


func _ready() -> void:
	add_to_group("flight_obstacle")
	origin = position
	t = phase
	_build()


# ------------------------------------------------------------------ collisions

func _center_at(dt: float) -> Vector3:
	if kind == "bird":
		return Vector3(origin.x + sin((t + dt) * speed) * amp, origin.y, origin.z)
	return origin


func _angle_at(dt: float) -> float:
	return (t + dt) * speed


# True if a sphere (centre `p`, radius `pr`) hits this obstacle `dt` seconds from now.
func check(p: Vector3, pr: float, dt := 0.0) -> bool:
	if absf(p.z - origin.z) > radius + 14.0:
		return false
	match kind:
		"rock", "balloon", "storm":
			return p.distance_to(origin) < radius + pr
		"bird":
			return p.distance_to(_center_at(dt)) < radius + pr
		"tower":
			if Vector2(p.x - origin.x, p.z - origin.z).length() < radius + pr and p.y < height + pr:
				return true
			return _bar_hit(Vector2(p.x - origin.x, p.y - (origin.y + height + 1.4)), absf(p.z - origin.z), pr, dt)
		"blimp":
			var a := Vector3(origin.x - half_len, origin.y, origin.z)
			var b := Vector3(origin.x + half_len, origin.y, origin.z)
			var ab := b - a
			var u := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			return p.distance_to(a + ab * u) < radius + pr
		"gate":
			return _bar_hit(Vector2(p.x - origin.x, p.y - origin.y), absf(p.z - origin.z), pr, dt)
	return false


func _bar_hit(local: Vector2, dz: float, pr: float, dt: float) -> bool:
	if dz > 1.2 + pr:
		return false
	var a := _angle_at(dt)
	var dir := Vector2(cos(a), sin(a))
	var along := local.dot(dir)
	var across := absf(local.x * -dir.y + local.y * dir.x)
	if local.length() < 1.6 + pr:
		return true                                    # the hub
	return absf(along) < bar_len + pr and across < 0.7 + pr


# ------------------------------------------------------------------ motion

func _physics_process(delta: float) -> void:
	t += delta
	match kind:
		"bird":
			position.x = _center_at(0.0).x
			for i in wings.size():
				wings[i].rotation.z = sin(t * 9.0) * 0.7 * (1.0 if i == 0 else -1.0)
		"gate", "tower":
			if spinner:
				spinner.rotation.z = _angle_at(0.0)
		"storm":
			var f := fmod(t * 0.7 + phase, 3.0) < 0.18
			for n in flash_nodes:
				n.visible = f
			if storm_light:
				storm_light.light_energy = 6.0 if f else 0.0
		"balloon":
			rotation.z = sin(t * 1.3 + phase) * 0.05


# ------------------------------------------------------------------ looks

func _build() -> void:
	match kind:
		"rock":
			_build_rock()
		"balloon":
			_build_balloon()
		"storm":
			_build_storm()
		"tower":
			_build_tower()
		"blimp":
			_build_blimp()
		"gate":
			_build_gate()
		"bird":
			_build_bird()


func _build_rock() -> void:
	var tex := T.noise_tex("fly_rock", Color(0.45, 0.4, 0.36), Color(0.72, 0.66, 0.58), 0.1, 128, 12)
	var stone := T.mat(Color.WHITE, true, 0.9, tex, 0.05)
	var grass := T.mat(Color(0.3, 0.7, 0.25), true, 0.8, null, 0.05)
	var r := radius * 0.82
	T.sphere(self, r, Vector3.ZERO, stone, Vector3(1.0, 0.85, 1.0))
	T.sphere(self, r * 0.6, Vector3(r * 0.45, -r * 0.2, r * 0.3), stone)
	T.sphere(self, r * 0.5, Vector3(-r * 0.5, r * 0.15, -r * 0.35), stone)
	T.sphere(self, r * 0.72, Vector3(0, r * 0.42, 0), grass, Vector3(1.1, 0.4, 1.1))
	T.cylinder(self, 0.0, r * 0.5, r * 1.1, Vector3(0, -r * 0.95, 0), stone, 8)


func _build_balloon() -> void:
	var stripes := [Color(0.95, 0.25, 0.25), Color(1.0, 0.85, 0.2), Color(0.25, 0.6, 1.0), Color(0.4, 0.85, 0.4)]
	var c: Color = stripes[int(absf(phase * 7.0 + origin.x)) % 4]
	var env := T.mat(c, true, 0.5, null, 0.05)
	var white := T.mat(Color.WHITE, false, 0.5)
	T.sphere(self, radius * 0.95, Vector3.ZERO, env, Vector3(0.95, 1.15, 0.95))
	for i in 2:
		var band := T.torus(self, radius * 0.55, radius * 0.62, Vector3(0, (i - 0.5) * radius * 0.9, 0), white)
		band.scale = Vector3(1.0, 0.25, 1.0)
	T.box(self, Vector3(1.4, 1.0, 1.4), Vector3(0, -radius * 1.55, 0), T.mat(Color(0.55, 0.35, 0.18), true))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var rope := T.cylinder(self, 0.04, 0.04, radius * 0.75, Vector3(sx * 0.55, -radius * 1.1, sz * 0.55), white, 4)
			rope.rotation = Vector3(sz * 0.12, 0, -sx * 0.12)
	T.sphere(self, 0.3, Vector3(0, -radius * 1.0, 0), T.emissive(Color(1.0, 0.6, 0.2), 2.5))


func _build_storm() -> void:
	var dark := T.mat(Color(0.30, 0.31, 0.38), false, 0.9)
	var darker := T.mat(Color(0.2, 0.21, 0.27), false, 0.9)
	var r := radius * 0.7
	T.sphere(self, r, Vector3.ZERO, dark)
	for i in 6:
		var a := TAU * i / 6.0
		T.sphere(self, r * 0.7, Vector3(cos(a) * r * 0.85, sin(a * 2.0) * r * 0.25, sin(a) * r * 0.85), darker if i % 2 == 0 else dark)
	T.sphere(self, r * 0.8, Vector3(0, r * 0.55, 0), dark)
	var bolt := Node3D.new()
	add_child(bolt)
	var glow := T.emissive(Color(1.0, 0.95, 0.5), 4.0)
	for i in 4:
		var seg := T.box(bolt, Vector3(0.35, r * 0.7, 0.35), Vector3(sin(i * 1.7) * 0.7, -r * 0.9 - i * r * 0.5, r * 0.4), glow)
		seg.rotation.z = (0.4 if i % 2 == 0 else -0.4)
	bolt.visible = false
	flash_nodes.append(bolt)
	storm_light = OmniLight3D.new()
	storm_light.light_color = Color(0.8, 0.85, 1.0)
	storm_light.omni_range = radius * 5.0
	storm_light.light_energy = 0.0
	add_child(storm_light)


func _build_tower() -> void:
	var white := T.mat(Color(0.96, 0.94, 0.9), true, 0.6, null, 0.06)
	var red := T.mat(Color(0.85, 0.2, 0.15), true, 0.6, null, 0.06)
	var wood := T.mat(Color(0.5, 0.33, 0.2), true, 0.7, null, 0.05)
	var base_y := -40.0 - origin.y
	var len_t := height - base_y
	T.cylinder(self, radius * 0.7, radius * 1.3, len_t, Vector3(0, base_y + len_t * 0.5, 0), white, 16)
	for i in 4:
		T.cylinder(self, radius * 0.72, radius * 0.72, 1.0, Vector3(0, height - 2.0 - i * 3.0, 0), red, 16)
	T.cylinder(self, radius * 0.85, radius * 0.5, 2.2, Vector3(0, height + 0.8, 0), wood, 16)
	T.cone_roof(self, radius, height + 2.0)
	spinner = Node3D.new()
	spinner.position = Vector3(0, height + 1.4, radius * 0.9)
	add_child(spinner)
	T.sphere(spinner, 0.7, Vector3.ZERO, red)
	for i in 4:
		var blade := Node3D.new()
		blade.rotation.z = i * PI / 2.0
		spinner.add_child(blade)
		T.box(blade, Vector3(1.1, bar_len * 0.5, 0.18), Vector3(0, bar_len * 0.25 + 0.5, 0), white)


func _build_blimp() -> void:
	var leaf := T.noise_tex("tobacco", Color(0.30, 0.16, 0.06), Color(0.56, 0.34, 0.15), 0.09, 128, 31)
	var skin := T.mat(Color.WHITE, true, 0.75, leaf, 0.06)
	var gold := T.mat(Color(0.95, 0.75, 0.2), true, 0.25, null, 0.05)
	var red := T.mat(Color(0.7, 0.08, 0.08), true, 0.4, null, 0.05)
	var body := T.capsule(self, radius, half_len * 2.0 + radius, Vector3.ZERO, skin)
	body.rotation.z = PI / 2.0
	for sx in [-0.45, 0.2]:
		var band := T.cylinder(self, radius * 1.03, radius * 1.03, 1.2, Vector3(sx * half_len, 0, 0), red, 20)
		band.rotation.z = PI / 2.0
	var tip := T.sphere(self, radius * 0.9, Vector3(half_len + radius * 0.8, 0, 0), T.emissive(Color(1.0, 0.45, 0.1), 2.0))
	tip.scale = Vector3(0.6, 1.0, 1.0)
	T.box(self, Vector3(5.0, 0.5, 2.6), Vector3(-half_len, 0, 0), gold)
	T.box(self, Vector3(1.6, radius * 2.2, 0.5), Vector3(-half_len, 0, 0), gold)
	for side in [1.0, -1.0]:
		var lab := Label3D.new()
		lab.text = "HUMO"
		lab.font_size = 160
		lab.pixel_size = 0.016
		lab.modulate = Color(1.0, 0.9, 0.5)
		lab.outline_modulate = Color(0.2, 0.05, 0.02)
		lab.outline_size = 22
		lab.shaded = false
		lab.position = Vector3(-half_len * 0.1, 0, side * (radius + 0.1))
		lab.rotation.y = 0.0 if side > 0.0 else PI
		add_child(lab)


func _build_gate() -> void:
	var frame := T.mat(Color(0.95, 0.9, 0.8), true, 0.5, null, 0.06)
	T.torus(self, bar_len + 1.2, bar_len + 1.9, Vector3.ZERO, frame).rotation.x = PI / 2.0
	spinner = Node3D.new()
	add_child(spinner)
	var stripe_a := T.mat(Color(0.95, 0.25, 0.2), true, 0.5, null, 0.05)
	var stripe_b := T.mat(Color(1.0, 0.9, 0.3), true, 0.5, null, 0.05)
	var n := 6
	for i in n:
		var seg_len := bar_len * 2.0 / n
		T.box(spinner, Vector3(seg_len, 1.0, 0.8), Vector3(-bar_len + seg_len * (i + 0.5), 0, 0), stripe_a if i % 2 == 0 else stripe_b)
	T.sphere(spinner, 1.7, Vector3.ZERO, T.mat(Color(0.3, 0.3, 0.36), true))


func _build_bird() -> void:
	var white := T.mat(Color(0.97, 0.97, 1.0), true, 0.5, null, 0.04)
	var orange := T.mat(Color(1.0, 0.6, 0.1), false)
	var tilt := Node3D.new()
	add_child(tilt)
	T.sphere(tilt, 0.7, Vector3.ZERO, white, Vector3(0.9, 0.8, 1.5))
	T.sphere(tilt, 0.42, Vector3(0, 0.25, -1.0), white)
	T.cylinder(tilt, 0.0, 0.14, 0.5, Vector3(0, 0.2, -1.5), orange, 6).rotation.x = -PI / 2.0
	for sx in [-1.0, 1.0]:
		T.sphere(tilt, 0.08, Vector3(sx * 0.2, 0.4, -1.3), T.mat(Color(0.05, 0.05, 0.1), false))
		var wing := Node3D.new()
		wing.position = Vector3(sx * 0.5, 0.2, 0)
		tilt.add_child(wing)
		T.box(wing, Vector3(2.1, 0.1, 0.9), Vector3(sx * 1.05, 0, 0), white)
		wings.append(wing)
