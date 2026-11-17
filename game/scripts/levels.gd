extends RefCounted
# Level definitions. Each builds into a Node3D root and returns the info dictionary.

const Kit = preload("res://scripts/level_kit.gd")

# Level order. Add new levels here (and in build()); tests and menus look levels up by key via idx().
const KEYS := ["jungle", "boulder", "cigar", "sewer", "city", "beach", "snow", "sky", "brewery"]
const NAMES := ["1. JUNGLE RUN", "2. BOULDER RUSH", "3. DON HUMO", "4. SEWER SURGE", "5. NEON ROOFTOPS", "6. SUNNY SHORES", "7. FROZEN PEAKS", "8. PALMOUZE AIRWAYS", "9. THE BREWMASTER"]
const COUNT := 9


static func idx(key: String) -> int:
	return KEYS.find(key)

const THEMES := {
	"jungle": {
		"name": "jungle",
		"top_a": Color(0.17, 0.46, 0.15), "top_b": Color(0.32, 0.66, 0.20),
		"path_a": Color(0.64, 0.50, 0.34), "path_b": Color(0.84, 0.70, 0.48),
		"dirt_a": Color(0.40, 0.25, 0.15), "dirt_b": Color(0.58, 0.37, 0.22),
		"lip": Color(0.58, 0.52, 0.44),
		"leaf_a": Color(0.12, 0.45, 0.19), "leaf_b": Color(0.26, 0.62, 0.22),
		"water": Color(0.15, 0.55, 0.85, 1.0),
		"mountain": Color(0.30, 0.55, 0.60), "pillar": Color.WHITE,
		"sky_top": Color(0.13, 0.38, 0.88), "sky_horizon": Color(0.70, 0.86, 0.98),
		"ground_horizon": Color(0.70, 0.86, 0.98), "ground_bottom": Color(0.16, 0.38, 0.32),
		"fog": Color(0.62, 0.80, 0.92), "fog_density": 0.0024,
		"sun_color": Color(1.0, 0.95, 0.82), "sun_energy": 1.15, "sun_rot": Vector3(-50, -35, 0),
		"ambient": 0.5,
	},
	"sewer": {
		"name": "sewer", "brick": true,
		"top_a": Color(0.3, 0.38, 0.3), "top_b": Color(0.45, 0.52, 0.4),
		"path_a": Color(0.36, 0.40, 0.38), "path_b": Color(0.56, 0.60, 0.54),
		"dirt_a": Color(0.45, 0.27, 0.22), "dirt_b": Color(0.62, 0.40, 0.30),
		"lip": Color(0.50, 0.58, 0.48),
		"leaf_a": Color(0.2, 0.4, 0.2), "leaf_b": Color(0.3, 0.5, 0.2),
		"water": Color(0.15, 0.27, 0.06, 1.0),
		"mountain": Color(0.2, 0.3, 0.2), "pillar": Color(0.5, 0.55, 0.5),
		"sky_top": Color(0.10, 0.20, 0.16), "sky_horizon": Color(0.20, 0.32, 0.22),
		"ground_horizon": Color(0.20, 0.32, 0.22), "ground_bottom": Color(0.10, 0.2, 0.12),
		"fog": Color(0.10, 0.20, 0.13), "fog_density": 0.009,
		"sun_color": Color(0.75, 0.95, 0.8), "sun_energy": 0.45, "sun_rot": Vector3(-60, -25, 0),
		"ambient": 1.1,
	},
	"city": {
		"name": "city", "facade": true,
		"top_a": Color(0.30, 0.31, 0.36), "top_b": Color(0.46, 0.47, 0.52),
		"path_a": Color(0.27, 0.29, 0.34), "path_b": Color(0.40, 0.42, 0.48),
		"dirt_a": Color(0.20, 0.22, 0.32), "dirt_b": Color(0.34, 0.36, 0.48),
		"lip": Color(0.72, 0.72, 0.78),
		"leaf_a": Color(0.2, 0.4, 0.2), "leaf_b": Color(0.3, 0.5, 0.2),
		"water": Color(0.07, 0.07, 0.11, 1.0),
		"mountain": Color(0.34, 0.26, 0.48), "pillar": Color.WHITE,
		"sky_top": Color(0.20, 0.16, 0.46), "sky_horizon": Color(1.0, 0.50, 0.34),
		"ground_horizon": Color(1.0, 0.50, 0.34), "ground_bottom": Color(0.25, 0.12, 0.22),
		"fog": Color(0.80, 0.42, 0.46), "fog_density": 0.0038,
		"sun_color": Color(1.0, 0.60, 0.38), "sun_energy": 1.35, "sun_rot": Vector3(-14, 165, 0),
		"ambient": 0.95,
	},
	"beach": {
		"name": "beach", "palms_only": true,
		"top_a": Color(0.93, 0.82, 0.56), "top_b": Color(1.0, 0.92, 0.68),
		"path_a": Color(0.93, 0.82, 0.56), "path_b": Color(1.0, 0.92, 0.70),
		"dirt_a": Color(0.78, 0.62, 0.40), "dirt_b": Color(0.90, 0.76, 0.52),
		"lip": Color(0.86, 0.72, 0.52),
		"leaf_a": Color(0.15, 0.55, 0.22), "leaf_b": Color(0.30, 0.72, 0.28),
		"water": Color(0.05, 0.62, 0.78, 1.0),
		"mountain": Color(0.30, 0.62, 0.55), "pillar": Color.WHITE,
		"sky_top": Color(0.10, 0.50, 0.96), "sky_horizon": Color(0.76, 0.93, 1.0),
		"ground_horizon": Color(0.76, 0.93, 1.0), "ground_bottom": Color(0.10, 0.50, 0.58),
		"fog": Color(0.70, 0.90, 1.0), "fog_density": 0.0016,
		"sun_color": Color(1.0, 0.97, 0.86), "sun_energy": 1.35, "sun_rot": Vector3(-48, -30, 0),
		"ambient": 0.85,
	},
	"snow": {
		"name": "snow", "pines": true, "snow": true,
		"top_a": Color(0.84, 0.90, 0.97), "top_b": Color(1.0, 1.0, 1.0),
		"path_a": Color(0.86, 0.92, 0.99), "path_b": Color(1.0, 1.0, 1.0),
		"dirt_a": Color(0.42, 0.48, 0.60), "dirt_b": Color(0.60, 0.67, 0.78),
		"lip": Color(0.70, 0.86, 0.96),
		"leaf_a": Color(0.12, 0.36, 0.26), "leaf_b": Color(0.20, 0.46, 0.30),
		"water": Color(0.04, 0.18, 0.38, 1.0),
		"mountain": Color(0.82, 0.89, 0.97), "pillar": Color.WHITE,
		"sky_top": Color(0.40, 0.58, 0.86), "sky_horizon": Color(0.86, 0.91, 0.98),
		"ground_horizon": Color(0.86, 0.91, 0.98), "ground_bottom": Color(0.55, 0.65, 0.8),
		"fog": Color(0.82, 0.88, 0.96), "fog_density": 0.0036,
		"sun_color": Color(0.96, 0.96, 1.0), "sun_energy": 0.95, "sun_rot": Vector3(-42, -30, 0),
		"ambient": 0.9,
	},
	"brewery": {
		"name": "brewery", "brick": true,
		"top_a": Color(0.4, 0.26, 0.16), "top_b": Color(0.55, 0.36, 0.22),
		"path_a": Color(0.5, 0.32, 0.18), "path_b": Color(0.72, 0.5, 0.3),
		"dirt_a": Color(0.50, 0.26, 0.18), "dirt_b": Color(0.70, 0.40, 0.28),
		"lip": Color(0.62, 0.45, 0.28),
		"leaf_a": Color(0.2, 0.4, 0.2), "leaf_b": Color(0.3, 0.5, 0.2),
		"water": Color(0.55, 0.32, 0.08, 1.0),
		"mountain": Color(0.3, 0.2, 0.15), "pillar": Color(0.6, 0.45, 0.3),
		"sky_top": Color(0.16, 0.10, 0.07), "sky_horizon": Color(0.30, 0.18, 0.10),
		"ground_horizon": Color(0.30, 0.18, 0.10), "ground_bottom": Color(0.14, 0.08, 0.05),
		"fog": Color(0.20, 0.12, 0.07), "fog_density": 0.006,
		"sun_color": Color(1.0, 0.8, 0.55), "sun_energy": 0.5, "sun_rot": Vector3(-60, -25, 0),
		"ambient": 1.15,
	},
	"lounge": {
		"name": "lounge", "planks": true,
		"top_a": Color(0.4, 0.26, 0.16), "top_b": Color(0.55, 0.36, 0.22),
		"path_a": Color(0.42, 0.06, 0.09), "path_b": Color(0.62, 0.14, 0.14),
		"dirt_a": Color(0.20, 0.10, 0.07), "dirt_b": Color(0.36, 0.19, 0.11),
		"lip": Color(0.80, 0.62, 0.28),
		"leaf_a": Color(0.2, 0.4, 0.2), "leaf_b": Color(0.3, 0.5, 0.2),
		"water": Color(0.3, 0.2, 0.1, 1.0),
		"mountain": Color(0.3, 0.2, 0.15), "pillar": Color(0.6, 0.45, 0.3),
		"sky_top": Color(0.12, 0.09, 0.08), "sky_horizon": Color(0.26, 0.20, 0.16),
		"ground_horizon": Color(0.26, 0.20, 0.16), "ground_bottom": Color(0.10, 0.07, 0.06),
		"fog": Color(0.30, 0.25, 0.21), "fog_density": 0.011,
		"sun_color": Color(1.0, 0.8, 0.55), "sun_energy": 0.4, "sun_rot": Vector3(-60, -25, 0),
		"ambient": 1.2,
	},
	"sky": {
		"name": "sky",
		"top_a": Color(0.9, 0.93, 1.0), "top_b": Color(1.0, 1.0, 1.0),
		"path_a": Color(0.9, 0.93, 1.0), "path_b": Color(1.0, 1.0, 1.0),
		"dirt_a": Color(0.6, 0.65, 0.75), "dirt_b": Color(0.8, 0.84, 0.92),
		"lip": Color(0.9, 0.9, 0.95),
		"leaf_a": Color(0.2, 0.5, 0.25), "leaf_b": Color(0.3, 0.6, 0.3),
		"water": Color(0.74, 0.82, 0.95, 1.0),
		"mountain": Color(0.55, 0.62, 0.78), "pillar": Color.WHITE,
		"sky_top": Color(0.14, 0.44, 0.96), "sky_horizon": Color(0.96, 0.93, 0.86),
		"ground_horizon": Color(0.96, 0.93, 0.86), "ground_bottom": Color(0.7, 0.8, 0.95),
		"fog": Color(0.86, 0.91, 1.0), "fog_density": 0.0013,
		"sun_color": Color(1.0, 0.96, 0.86), "sun_energy": 1.3, "sun_rot": Vector3(-38, -30, 0),
		"ambient": 1.0,
	},
	"ruins": {
		"name": "ruins",
		"top_a": Color(0.82, 0.68, 0.42), "top_b": Color(0.95, 0.82, 0.55),
		"path_a": Color(0.82, 0.68, 0.42), "path_b": Color(0.95, 0.82, 0.55),
		"dirt_a": Color(0.58, 0.40, 0.28), "dirt_b": Color(0.76, 0.55, 0.38),
		"lip": Color(0.88, 0.80, 0.65),
		"leaf_a": Color(0.45, 0.65, 0.25), "leaf_b": Color(0.6, 0.78, 0.3),
		"water": Color(0.9, 0.45, 0.25, 1.0),
		"mountain": Color(0.75, 0.45, 0.35), "pillar": Color(0.95, 0.9, 0.8),
		"sky_top": Color(0.35, 0.35, 0.75), "sky_horizon": Color(1.0, 0.68, 0.42),
		"ground_horizon": Color(1.0, 0.68, 0.42), "ground_bottom": Color(0.5, 0.25, 0.2),
		"fog": Color(0.98, 0.7, 0.5), "fog_density": 0.006,
		"sun_color": Color(1.0, 0.78, 0.55), "sun_energy": 1.6, "sun_rot": Vector3(-28, 140, 0),
		"ambient": 0.8,
	},
}


static func build(index: int, root: Node3D) -> Dictionary:
	match index:
		0:
			return _jungle_run(root)
		1:
			return _boulder_rush(root)
		2:
			return _cigar_lounge(root)
		3:
			return _sewer_surge(root)
		4:
			return _city_run(root)
		5:
			return _beach_run(root)
		6:
			return _snow_run(root)
		7:
			return _sky_run(root)
		_:
			return _brewmaster(root)


# =============================================================== LEVEL 1
static func _jungle_run(root: Node3D) -> Dictionary:
	var theme: Dictionary = THEMES.jungle
	var k := Kit.new(root, theme)
	k.info.title = NAMES[0]
	k.info.theme = theme
	k.info.start = Vector3(0, 0.05, -1)
	k.info.kill_y = -11.0

	# --- A: start area, crates & fruit
	k.ground(0, 0, 6, -34, 9)
	for x in [-2.5, 0.0, 2.5]:
		k.crate("basic", Vector3(x, 0, -9))
	k.fruit_line(Vector3(0, 0.7, -13), Vector3(0, 0.7, -24), 8)
	k.crate("bounce", Vector3(3.2, 0, -17))
	k.stack("basic", Vector3(-3.2, 0, -22), 2)
	k.fruit_arc(Vector3(0, 0.8, -31), Vector3(0, 0.8, -40), 6, 2.4)

	# --- B: first gap, a crab, shield
	k.ground(0, 0, -38, -58, 9)
	k.enemy("crab", Vector3(0, 0, -46), Vector3.RIGHT, 3.0, 1.8)
	k.crate("basic", Vector3(-3.5, 0, -52))
	k.crate("basic", Vector3(3.5, 0, -52))
	k.crate("mask", Vector3(0, 0, -55))
	k.fruit_line(Vector3(-3, 0.7, -42), Vector3(3, 0.7, -42), 5)

	# --- C: narrow bridge with a long gap (double jump)
	k.ground(0, 0, -63, -70, 3.6)
	k.ground(0, 0, -77, -92, 3.6)
	k.fruit_arc(Vector3(0, 1.0, -69), Vector3(0, 1.0, -78), 7, 3.2)
	k.fruit_line(Vector3(0, 0.7, -80), Vector3(0, 0.7, -90), 6)
	k.crate("basic", Vector3(0, 0, -85))

	# --- D: checkpoint plaza
	k.ground(0, 0, -92, -122, 12)
	k.crate("checkpoint", Vector3(0, 0, -95))
	k.stack("basic", Vector3(-4.5, 0, -100), 3)
	k.crate("iron", Vector3(-1.5, 0, -100))
	k.crate("basic", Vector3(-1.5, 1, -100))
	k.crate("boom", Vector3(2.5, 0, -103))
	k.crate("basic", Vector3(4.2, 0, -103))
	k.enemy("crab", Vector3(0, 0, -108), Vector3.RIGHT, 4.0, 1.5)
	k.enemy("spiky", Vector3(-3.5, 0, -111), Vector3.BACK, 2.0, 1.0)
	k.enemy("crab", Vector3(0, 0, -114), Vector3.RIGHT, 4.5, 2.0, 1.5)
	k.crate("bounce", Vector3(4.5, 0, -117))
	k.crate("iron", Vector3(-4.5, 0, -118))
	k.crate("life", Vector3(-4.5, 1, -118))
	k.fruit_line(Vector3(-4, 0.7, -106), Vector3(4, 0.7, -106), 6)

	# --- E: moving platforms over water
	k.mover(Vector3(0, -0.3, -128), Vector3(4.6, 0.6, 4.0), Vector3.RIGHT, 2.2, 1.1, 0.0)
	k.mover(Vector3(0, -0.3, -136), Vector3(4.6, 0.6, 4.0), Vector3.RIGHT, 2.2, 1.1, 0.5)
	k.mover(Vector3(0, -0.3, -144), Vector3(5.0, 0.6, 4.0), Vector3.RIGHT, 0.01, 1.0, 0.0)
	k.mover(Vector3(0, -0.3, -152), Vector3(4.4, 0.6, 4.0), Vector3.BACK, 1.2, 1.0, 0.0)
	k.fruit_arc(Vector3(0, 0.9, -124), Vector3(0, 0.9, -127), 3, 1.2)
	k.fruit_arc(Vector3(0, 0.9, -130), Vector3(0, 0.9, -134), 4, 1.6)
	k.fruit_arc(Vector3(0, 0.9, -138), Vector3(0, 0.9, -142), 4, 1.6)
	k.crate("basic", Vector3(1.4, 0, -144))
	k.fruit_arc(Vector3(0, 0.9, -146), Vector3(0, 0.9, -150), 4, 1.6)

	# --- F: spinner gauntlet
	k.ground(0, 0, -158, -192, 10)
	k.spinner(Vector3(0, 0, -166), 5.6, 1.25)
	k.spinner(Vector3(0, 0, -178), 5.6, -1.35)
	for z in [-162.0, -172.0, -184.0]:
		k.crate("basic", Vector3(-4.2, 0, z))
		k.crate("basic", Vector3(4.2, 0, z))
	k.crate("checkpoint", Vector3(0, 0, -187))
	k.fruit_line(Vector3(0, 0.7, -170), Vector3(0, 0.7, -174), 3)
	k.crate("bounce", Vector3(0, 0, -190))

	# --- G: stairs to the goal
	k.ground(0, 1, -192, -196, 8)
	k.ground(0, 2, -196, -200, 8)
	k.ground(0, 3, -200, -222, 11)
	k.crate("basic", Vector3(-3, 1, -194))
	k.crate("basic", Vector3(3, 1, -194))
	k.crate("basic", Vector3(-3, 2, -198))
	k.crate("basic", Vector3(3, 2, -198))
	k.fruit_line(Vector3(0, 3.7, -204), Vector3(0, 3.7, -210), 5)
	k.goal(Vector3(0, 3, -214))

	# --- world dressing: canyon cliffs, trees, water
	k.water(-9.0, -105.0, 260.0)
	for side in [-1.0, 1.0]:
		k.scenery_block(Vector3(side * 31.0, -13.0, -105.0), Vector3(44.0, 20.0, 290.0))
	k.scatter_trees(14.0, -240.0, -3.0, 11.0, 50.0, 140)
	k.mountains(-105.0)
	return k.info


# =============================================================== LEVEL 2
static func _boulder_rush(root: Node3D) -> Dictionary:
	var theme: Dictionary = THEMES.ruins
	var k := Kit.new(root, theme)
	k.info.title = NAMES[1]
	k.info.theme = theme
	k.info.start = Vector3(0, 0.05, -92)
	k.info.kill_y = -11.0
	# The camera sits in FRONT of the hero this time (he runs towards it).
	k.info.camera_offset = Vector3(0, 5.8, 10.0)
	k.info.camera_look = Vector3(0, 0.8, 3.5)

	var b: Node3D = k.boulder(Vector3(0, 3.2, -116), 7.2)

	# S1: warm-up
	k.ground(0, 0, -100, -50, 9)
	for x in [-3.0, 3.0]:
		k.crate("basic", Vector3(x, 0, -88))
	k.fruit_line(Vector3(0, 0.7, -86), Vector3(0, 0.7, -74), 7)
	k.rock(Vector3(-2.0, 0, -78), Vector3(4.2, 1.0, 1.2))
	k.rock(Vector3(2.0, 0, -66), Vector3(4.2, 1.0, 1.2))
	k.crate("bounce", Vector3(-3.2, 0, -60))
	k.fruit_line(Vector3(0, 0.7, -62), Vector3(0, 0.7, -54), 4)

	# S2: gap, crabs
	k.ground(0, 0, -45, -8, 9)
	k.fruit_arc(Vector3(0, 0.8, -52), Vector3(0, 0.8, -43), 6, 2.2)
	k.enemy("crab", Vector3(0, 0, -34), Vector3.RIGHT, 3.2, 2.0)
	k.rock(Vector3(0, 0, -26), Vector3(3.0, 1.0, 1.2))
	k.enemy("crab", Vector3(0, 0, -19), Vector3.RIGHT, 3.2, 2.4, 1.0)
	k.crate("mask", Vector3(-3.8, 0, -30))
	k.fruit_line(Vector3(3, 0.7, -40), Vector3(3, 0.7, -30), 5)

	# S3: checkpoint plaza
	k.ground(0, 0, -3, 18, 9)
	k.fruit_arc(Vector3(0, 0.8, -9), Vector3(0, 0.8, -2), 5, 2.2)
	k.crate("checkpoint", Vector3(0, 0, 2))
	k.crate("basic", Vector3(-3, 0, 8))
	k.crate("basic", Vector3(3, 0, 8))
	k.crate("life", Vector3(0, 0, 12))

	# S4: narrow causeway with a spinner
	k.ground(0, 0, 23, 56, 4.4)
	k.fruit_arc(Vector3(0, 0.8, 16), Vector3(0, 0.8, 24), 6, 2.2)
	k.spinner(Vector3(0, 0, 38), 5.4, 1.3)
	k.fruit_line(Vector3(0, 0.7, 28), Vector3(0, 0.7, 34), 4)
	k.fruit_line(Vector3(0, 0.7, 42), Vector3(0, 0.7, 52), 5)

	# S5: obstacle run
	k.ground(0, 0, 61, 100, 10)
	k.fruit_arc(Vector3(0, 0.8, 55), Vector3(0, 0.8, 62), 5, 2.2)
	k.rock(Vector3(-2.5, 0, 70), Vector3(5.0, 1.0, 1.2))
	k.rock(Vector3(2.5, 0, 78), Vector3(5.0, 1.0, 1.2))
	k.enemy("spiky", Vector3(0, 0, 86), Vector3.RIGHT, 3.5, 2.2)
	k.crate("boom", Vector3(3.5, 0, 92))
	k.crate("basic", Vector3(-3.5, 0, 92))
	k.fruit_line(Vector3(0, 0.7, 64), Vector3(0, 0.7, 68), 3)

	# S6: finish
	k.ground(0, 0, 105, 130, 11)
	k.fruit_arc(Vector3(0, 0.8, 99), Vector3(0, 0.8, 106), 5, 2.2)
	k.goal(Vector3(0, 0, 122))

	# dressing: temple walls, columns, torches, lava-ish pit glow
	k.water(-9.0, 15.0, 300.0)
	for side in [-1.0, 1.0]:
		k.scenery_block(Vector3(side * 20.0, 4.0, 15.0), Vector3(24.0, 28.0, 300.0), false)
	var z := -108.0
	var i := 0
	while z < 135.0:
		for side in [-1.0, 1.0]:
			k.pillar(Vector3(side * 8.2, 0, z), 7.0 + (i % 3), (i + (1 if side > 0 else 0)) % 4 == 0)
		if i % 2 == 0:
			k.torch(Vector3(-7.3, 1.5, z + 5.0))
			k.torch(Vector3(7.3, 1.5, z + 5.0))
		z += 14.0
		i += 1
	k.mountains(15.0)
	return k.info


# =============================================================== LEVEL 3
static func _sewer_surge(root: Node3D) -> Dictionary:
	var theme: Dictionary = THEMES.sewer
	var k := Kit.new(root, theme)
	k.info.title = NAMES[3]
	k.info.theme = theme
	k.info.start = Vector3(0, 0.05, -1)
	k.info.kill_y = -9.0

	# --- A: the outfall, slimes appear
	k.ground(0, 0, 6, -30, 8)
	for x in [-2.5, 0.0, 2.5]:
		k.crate("basic", Vector3(x, 0, -9))
	k.fruit_line(Vector3(0, 0.7, -13), Vector3(0, 0.7, -20), 5)
	k.crate("bounce", Vector3(3.0, 0, -16))
	k.enemy("slime", Vector3(0, 0, -23), Vector3.RIGHT, 2.5, 1.6)
	k.fruit_arc(Vector3(0, 0.8, -27), Vector3(0, 0.8, -35), 5, 2.2)

	# --- B: checkpoint, slimes, a boom crate
	k.ground(0, 0, -34, -60, 8)
	k.crate("checkpoint", Vector3(0, 0, -37))
	k.stack("basic", Vector3(-3.0, 0, -41), 2)
	k.enemy("slime", Vector3(0, 0, -46), Vector3.RIGHT, 3.0, 1.8)
	k.crate("boom", Vector3(3.0, 0, -50))
	k.enemy("slime", Vector3(0, 0, -53), Vector3.RIGHT, 3.0, 2.0, 1.5)
	k.crate("mask", Vector3(-3.2, 0, -57))
	k.fruit_line(Vector3(0, 0.7, -39), Vector3(0, 0.7, -44), 4)

	# --- C: crumbling grates over the sludge (keep moving!)
	for i in 5:
		k.crumble(Vector3(0, -0.25, -64.0 - i * 4.8))
	k.fruit_line(Vector3(0, 1.0, -62), Vector3(0, 1.0, -86), 9)

	# --- D: toy gauntlet
	k.ground(0, 0, -89, -118, 8)
	k.crate("checkpoint", Vector3(0, 0, -91.5))
	k.crate("basic", Vector3(-3.2, 0, -96))
	k.crate("basic", Vector3(3.2, 0, -96))
	k.spinner(Vector3(0, 0, -101), 5.4, 1.3)
	k.crate("basic", Vector3(-3.2, 0, -105))
	k.crate("basic", Vector3(3.2, 0, -105))
	k.enemy("slime", Vector3(0, 0, -110), Vector3.RIGHT, 3.0, 2.0)
	k.crate("bounce", Vector3(-3.0, 0, -114))
	k.fruit_line(Vector3(0, 0.7, -94), Vector3(0, 0.7, -98), 3)

	# --- E: moving platforms over the sludge
	k.mover(Vector3(0, -0.3, -127), Vector3(4.6, 0.6, 4.0), Vector3.RIGHT, 2.2, 1.1, 0.0)
	k.mover(Vector3(0, -0.3, -135), Vector3(4.6, 0.6, 4.0), Vector3.RIGHT, 2.2, 1.1, 0.5)
	k.mover(Vector3(0, -0.3, -143), Vector3(4.6, 0.6, 4.0), Vector3.RIGHT, 2.2, 1.1, 1.0)
	k.fruit_arc(Vector3(0, 0.9, -122), Vector3(0, 0.9, -126), 4, 1.5)
	k.fruit_arc(Vector3(0, 0.9, -129), Vector3(0, 0.9, -133), 4, 1.6)
	k.fruit_arc(Vector3(0, 0.9, -137), Vector3(0, 0.9, -141), 4, 1.6)

	# --- F: the pump room, two spinners
	k.ground(0, 0, -149, -186, 9)
	k.crate("checkpoint", Vector3(0, 0, -152))
	k.spinner(Vector3(0, 0, -160), 5.8, 1.25)
	k.enemy("slime", Vector3(0, 0, -166), Vector3.RIGHT, 3.5, 2.0)
	k.spinner(Vector3(0, 0, -172), 5.8, -1.35)
	k.crate("iron", Vector3(-3.8, 0, -178))
	k.crate("life", Vector3(-3.8, 1, -178))
	k.crate("basic", Vector3(3.8, 0, -178))
	k.crate("bounce", Vector3(0, 0, -182))
	k.fruit_line(Vector3(0, 0.7, -154), Vector3(0, 0.7, -158), 3)
	k.fruit_line(Vector3(0, 0.7, -175), Vector3(0, 0.7, -180), 3)

	# --- G: the exit shaft
	k.ground(0, 0, -190, -218, 10)
	for x in [-3.0, 3.0]:
		k.stack("basic", Vector3(x, 0, -196), 2)
	k.fruit_arc(Vector3(0, 0.8, -184), Vector3(0, 0.8, -192), 5, 2.2)
	k.fruit_line(Vector3(0, 0.7, -198), Vector3(0, 0.7, -204), 5)
	k.goal(Vector3(0, 0, -210))

	# --- world dressing: the tunnel and the toxic sludge
	k.water(-4.0, -106.0, 240.0)
	k.tunnel(12.0, -222.0)
	return k.info


# =============================================================== LEVEL 4
static func _city_run(root: Node3D) -> Dictionary:
	var theme: Dictionary = THEMES.city
	var k := Kit.new(root, theme)
	k.info.title = NAMES[4]
	k.info.theme = theme
	k.info.start = Vector3(0, 0.05, -1)
	k.info.kill_y = -14.0
	var D := 40.0    # the rooftops are the tops of tall buildings

	# --- A: first rooftop, drones appear
	k.ground(0, 0, 6, -38, 8, D)
	for x in [-2.5, 0.0, 2.5]:
		k.crate("basic", Vector3(x, 0, -9))
	k.fruit_line(Vector3(0, 0.7, -12), Vector3(0, 0.7, -20), 5)
	k.crate("bounce", Vector3(3.2, 0, -16))
	k.enemy("drone", Vector3(0, 0, -24), Vector3.RIGHT, 3.0, 1.8)
	k.rock(Vector3(-2.0, 0, -31), Vector3(3.4, 1.3, 1.8))     # an air-conditioning unit
	k.fruit_arc(Vector3(0, 0.8, -35), Vector3(0, 0.8, -44), 6, 2.4)

	# --- B: conveyor belt rooftop (a speed boost: carries you forward, away from the camera)
	k.ground(0, 0, -43, -53, 8, D)
	k.crate("checkpoint", Vector3(0, 0, -45.5))
	k.conveyor(0.0, -53, -65, 8, Vector3(0, 0, -1), 4.5)
	k.crate("basic", Vector3(-3.3, 0, -59))
	k.crate("basic", Vector3(3.3, 0, -59))
	k.fruit_line(Vector3(0, 0.7, -55), Vector3(0, 0.7, -63), 5)
	k.ground(0, 0, -65, -80, 8, D)
	k.enemy("drone", Vector3(0, 0, -72), Vector3.RIGHT, 3.0, 2.0)
	k.crate("boom", Vector3(3.2, 0, -69))
	k.crate("mask", Vector3(-3.2, 0, -76))

	# --- C: stairs up the building
	k.ground(0, 0, -85, -97, 8, D)
	k.fruit_arc(Vector3(0, 0.8, -79), Vector3(0, 0.8, -86), 5, 2.2)
	k.ground(0, 1.3, -97, -109, 8, D)
	k.crate("basic", Vector3(-3, 1.3, -103))
	k.crate("basic", Vector3(3, 1.3, -103))
	k.ground(0, 2.6, -109, -121, 8, D)
	k.crate("checkpoint", Vector3(0, 2.6, -112))
	k.enemy("drone", Vector3(0, 2.6, -117), Vector3.RIGHT, 3.0, 2.0)

	# --- D: moving platforms between towers
	k.mover(Vector3(0, 2.3, -127.5), Vector3(4.6, 0.6, 4.0), Vector3.RIGHT, 2.2, 1.1, 0.0)
	k.mover(Vector3(0, 2.3, -135.5), Vector3(4.6, 0.6, 4.0), Vector3.RIGHT, 2.2, 1.1, 0.5)
	k.mover(Vector3(0, 2.3, -143.5), Vector3(4.6, 0.6, 4.0), Vector3.RIGHT, 2.2, 1.1, 1.0)
	k.fruit_arc(Vector3(0, 3.5, -123), Vector3(0, 3.5, -126), 4, 1.5)
	k.fruit_arc(Vector3(0, 3.5, -130), Vector3(0, 3.5, -134), 4, 1.6)
	k.fruit_arc(Vector3(0, 3.5, -138), Vector3(0, 3.5, -142), 4, 1.6)

	# --- E: the roof garden: spinners and drones
	k.ground(0, 2.6, -150, -190, 9, D)
	k.crate("checkpoint", Vector3(0, 2.6, -153))
	k.spinner(Vector3(0, 2.6, -162), 5.8, 1.25)
	k.enemy("drone", Vector3(0, 2.6, -168), Vector3.RIGHT, 3.5, 2.0)
	k.spinner(Vector3(0, 2.6, -176), 5.8, -1.35)
	k.crate("iron", Vector3(-3.8, 2.6, -182))
	k.crate("life", Vector3(-3.8, 3.6, -182))
	k.crate("bounce", Vector3(3.8, 2.6, -182))
	k.fruit_line(Vector3(0, 3.3, -156), Vector3(0, 3.3, -160), 3)
	k.fruit_line(Vector3(0, 3.3, -179), Vector3(0, 3.3, -186), 4)

	# --- F: scaffolding over the street
	for i in 5:
		k.crumble(Vector3(0, 2.35, -194.0 - i * 4.8))
	k.fruit_line(Vector3(0, 3.6, -192), Vector3(0, 3.6, -214), 8)

	# --- G: the final rooftop
	k.ground(0, 2.6, -219, -250, 10, D)
	for x in [-3.0, 3.0]:
		k.stack("basic", Vector3(x, 2.6, -225), 2)
	k.fruit_line(Vector3(0, 3.3, -228), Vector3(0, 3.3, -234), 5)
	k.goal(Vector3(0, 2.6, -241))

	# --- the city
	k.water(-48.0, -120.0, 300.0)
	k.skyline(14.0, -255.0)
	var signs := [["PALMOUZE", Color(1.0, 0.3, 0.7)], ["BAR", Color(0.3, 0.9, 1.0)], ["PIZZA", Color(1.0, 0.85, 0.2)],
		["FART-CAFE", Color(0.5, 1.0, 0.4)], ["HOTEL", Color(1.0, 0.45, 0.2)], ["24H", Color(0.7, 0.5, 1.0)]]
	var si := 0
	var z := -14.0
	while z > -245.0:
		var sg: Array = signs[si % signs.size()]
		var side := -1.0 if si % 2 == 0 else 1.0
		k.neon_sign(Vector3(side * 9.7, 7.0 + (si % 3) * 2.5, z), sg[0], sg[1], -side * PI * 0.5)
		si += 1
		z -= 26.0
	return k.info


# =============================================================== LEVEL 5
static func _beach_run(root: Node3D) -> Dictionary:
	var theme: Dictionary = THEMES.beach
	var k := Kit.new(root, theme)
	k.info.title = NAMES[5]
	k.info.theme = theme
	k.info.start = Vector3(0, 0.05, -1)
	k.info.kill_y = -7.0

	# --- A: the beach
	k.ground(0, 0, 6, -40, 9)
	for x in [-2.5, 0.0, 2.5]:
		k.crate("basic", Vector3(x, 0, -9))
	k.castle(Vector3(-2.2, 0, -14))
	k.crate("bounce", Vector3(3.4, 0, -19))
	k.enemy("crab", Vector3(0, 0, -25), Vector3.RIGHT, 3.2, 1.8)
	k.enemy("crab", Vector3(0, 0, -32), Vector3.RIGHT, 3.2, 2.2, 1.5)
	k.crate("mask", Vector3(-3.4, 0, -36))
	k.fruit_line(Vector3(0, 0.7, -12), Vector3(0, 0.7, -22), 6)
	k.fruit_arc(Vector3(0, 0.8, -38), Vector3(0, 0.8, -47), 6, 2.4)

	# --- B: the boardwalk, with gaps
	k.ground(0, 0, -45, -57, 6, 3.0, "wood")
	k.crate("checkpoint", Vector3(0, 0, -47.5))
	k.crate("basic", Vector3(-1.8, 0, -53))
	k.crate("basic", Vector3(1.8, 0, -53))
	k.ground(0, 0, -61, -73, 6, 3.0, "wood")
	k.crate("boom", Vector3(1.8, 0, -67))
	k.fruit_line(Vector3(0, 0.7, -63), Vector3(0, 0.7, -71), 5)
	k.ground(0, 0, -77, -89, 6, 3.0, "wood")
	k.enemy("spiky", Vector3(0, 0, -83), Vector3.BACK, 3.0, 1.4)
	k.fruit_arc(Vector3(0, 0.8, -57), Vector3(0, 0.8, -61), 3, 1.5)
	k.fruit_arc(Vector3(0, 0.8, -73), Vector3(0, 0.8, -77), 3, 1.5)

	# --- C: rafts on the open sea
	k.mover(Vector3(0, -0.3, -96), Vector3(4.6, 0.6, 4.0), Vector3.RIGHT, 2.2, 1.1, 0.0, "wood")
	k.mover(Vector3(0, -0.3, -104), Vector3(4.6, 0.6, 4.0), Vector3.BACK, 1.2, 1.0, 0.0, "wood")
	k.mover(Vector3(0, -0.3, -112), Vector3(4.6, 0.6, 4.0), Vector3.RIGHT, 2.2, 1.1, 0.5, "wood")
	k.fruit_arc(Vector3(0, 0.9, -91), Vector3(0, 0.9, -95), 4, 1.5)
	k.fruit_arc(Vector3(0, 0.9, -98), Vector3(0, 0.9, -102), 4, 1.6)
	k.fruit_arc(Vector3(0, 0.9, -106), Vector3(0, 0.9, -110), 4, 1.6)

	# --- D: the island with tidal waves
	k.ground(0, 0, -118.5, -155, 10)
	k.crate("checkpoint", Vector3(0, 0, -121.5))
	k.enemy("crab", Vector3(0, 0, -125), Vector3.RIGHT, 3.5, 2.0)
	k.wave(-132, 0.0, 10.0, 0.0)
	k.crate("basic", Vector3(-3.6, 0, -136))
	k.crate("basic", Vector3(3.6, 0, -136))
	k.wave(-141, 0.0, 10.0, 2.4)
	k.crate("iron", Vector3(-3.8, 0, -146))
	k.crate("life", Vector3(-3.8, 1, -146))
	k.enemy("spiky", Vector3(0, 0, -148), Vector3.RIGHT, 3.5, 2.0)
	k.crate("bounce", Vector3(3.8, 0, -150))
	k.fruit_line(Vector3(0, 0.7, -123), Vector3(0, 0.7, -130), 4)

	# --- E: the rotten pier
	for i in 6:
		k.crumble(Vector3(0, -0.25, -157.4 - i * 4.8), Vector3(3.4, 0.5, 3.6), "wood")
	k.fruit_line(Vector3(0, 1.0, -156), Vector3(0, 1.0, -184), 9)

	# --- F: the last stretch of sand
	k.ground(0, 0, -186, -232, 10)
	k.enemy("crab", Vector3(0, 0, -192), Vector3.RIGHT, 3.5, 2.0)
	k.wave(-199, 0.0, 10.0, 1.2)
	k.crate("basic", Vector3(-3.6, 0, -204))
	k.crate("basic", Vector3(3.6, 0, -204))
	k.spinner(Vector3(0, 0, -212), 5.4, 1.3)
	k.crate("checkpoint", Vector3(0, 0, -194))
	k.stack("basic", Vector3(-3.4, 0, -218), 2)
	k.stack("basic", Vector3(3.4, 0, -218), 2)
	k.fruit_line(Vector3(0, 0.7, -214), Vector3(0, 0.7, -224), 5)
	k.goal(Vector3(0, 0, -226))

	# --- the sea, the shore, palms, parasols
	k.water(-2.5, -118.0, 290.0)
	k.scenery_block(Vector3(34.0, -6.2, -110.0), Vector3(52.0, 10.0, 300.0))
	k.scatter_trees(14.0, -240.0, -1.2, 10.5, 50.0, 90, 1.0)
	for i in 8:
		var uz := -18.0 - i * 28.0
		k.umbrella(Vector3(10.0 + (i % 3) * 1.6, -1.2, uz), [Color(1.0, 0.3, 0.3), Color(1.0, 0.8, 0.2), Color(0.3, 0.6, 1.0)][i % 3])
	k.lifeguard_tower(Vector3(13.0, -1.2, -70.0), -PI * 0.5)
	k.lifeguard_tower(Vector3(13.0, -1.2, -180.0), -PI * 0.5)
	k.mountains(-110.0)
	return k.info


# =============================================================== LEVEL 6
static func _snow_run(root: Node3D) -> Dictionary:
	var theme: Dictionary = THEMES.snow
	var k := Kit.new(root, theme)
	k.info.title = NAMES[6]
	k.info.theme = theme
	k.info.start = Vector3(0, 0.05, -1)
	k.info.kill_y = -9.0

	# --- A: snowy trail, the first ice patch
	k.ground(0, 0, 6, -18, 9, 8.0, "snow")
	for x in [-2.5, 0.0, 2.5]:
		k.crate("basic", Vector3(x, 0, -9))
	k.crate("bounce", Vector3(3.4, 0, -14))
	k.fruit_line(Vector3(0, 0.7, -11), Vector3(0, 0.7, -17), 4)
	k.ground(0, 0, -18, -30, 9, 8.0, "ice")
	k.enemy("penguin", Vector3(0, 0, -24), Vector3.RIGHT, 3.0, 1.3)
	k.crate("basic", Vector3(-3.4, 0, -21))
	k.crate("basic", Vector3(3.4, 0, -27))
	k.ground(0, 0, -30, -40, 9, 8.0, "snow")
	k.crate("checkpoint", Vector3(0, 0, -33))
	k.crate("mask", Vector3(-3.4, 0, -37))
	k.fruit_arc(Vector3(0, 0.8, -38), Vector3(0, 0.8, -47), 6, 2.4)

	# --- B: ice floes
	k.mover(Vector3(0, -0.3, -47), Vector3(4.6, 0.6, 4.0), Vector3.RIGHT, 2.2, 1.1, 0.0, "ice")
	k.mover(Vector3(0, -0.3, -55), Vector3(4.6, 0.6, 4.0), Vector3.RIGHT, 2.2, 1.1, 0.5, "ice")
	k.mover(Vector3(0, -0.3, -63), Vector3(4.6, 0.6, 4.0), Vector3.RIGHT, 2.2, 1.1, 1.0, "ice")
	k.fruit_arc(Vector3(0, 0.9, -42), Vector3(0, 0.9, -46), 4, 1.5)
	k.fruit_arc(Vector3(0, 0.9, -49), Vector3(0, 0.9, -53), 4, 1.6)
	k.fruit_arc(Vector3(0, 0.9, -57), Vector3(0, 0.9, -61), 4, 1.6)

	# --- C: thin ice that cracks under you
	for i in 5:
		k.crumble(Vector3(0, -0.25, -68.6 - i * 4.8), Vector3(3.6, 0.5, 3.6), "ice")
	k.fruit_line(Vector3(0, 1.0, -67), Vector3(0, 1.0, -90), 8)

	# --- D: the ice rink
	k.ground(0, 0, -93, -140, 8, 8.0, "ice")
	k.crate("checkpoint", Vector3(0, 0, -98))
	k.crate("basic", Vector3(-3.2, 0, -104))
	k.crate("basic", Vector3(3.2, 0, -104))
	k.spinner(Vector3(0, 0, -109), 5.4, 1.3)
	k.enemy("penguin", Vector3(0, 0, -115), Vector3.RIGHT, 3.0, 1.5)
	k.spinner(Vector3(0, 0, -122), 5.4, -1.3)
	k.crate("boom", Vector3(3.0, 0, -128))
	k.crate("bounce", Vector3(-3.2, 0, -130))
	k.enemy("penguin", Vector3(0, 0, -134), Vector3.RIGHT, 3.0, 1.8, 1.0)
	k.fruit_line(Vector3(0, 0.7, -100), Vector3(0, 0.7, -106), 4)

	# --- E: the climb
	k.ground(0, 1.3, -140, -152, 9, 8.0, "snow")
	k.crate("basic", Vector3(-3, 1.3, -146))
	k.crate("basic", Vector3(3, 1.3, -146))
	k.ground(0, 2.6, -152, -164, 9, 8.0, "snow")
	k.enemy("penguin", Vector3(0, 2.6, -158), Vector3.RIGHT, 3.0, 1.6)
	k.crate("checkpoint", Vector3(0, 2.6, -155))

	# --- F: the summit
	k.ground(0, 3.9, -164, -250, 10, 8.0, "snow")
	k.crate("iron", Vector3(-3.8, 3.9, -170))
	k.crate("life", Vector3(-3.8, 4.9, -170))
	k.enemy("penguin", Vector3(0, 3.9, -176), Vector3.RIGHT, 3.5, 1.7)
	k.spinner(Vector3(0, 3.9, -188), 5.8, 1.25)
	k.crate("bounce", Vector3(3.6, 3.9, -194))
	k.enemy("penguin", Vector3(0, 3.9, -202), Vector3.RIGHT, 3.5, 2.0, 0.7)
	for x in [-3.2, 3.2]:
		k.stack("basic", Vector3(x, 3.9, -208), 2)
	k.fruit_line(Vector3(0, 4.6, -178), Vector3(0, 4.6, -186), 4)
	k.fruit_line(Vector3(0, 4.6, -210), Vector3(0, 4.6, -218), 5)
	k.goal(Vector3(0, 3.9, -228))

	# --- the mountains, the frozen lake, snowmen
	k.water(-3.0, -120.0, 300.0)
	for side in [-1.0, 1.0]:
		k.scenery_block(Vector3(side * 33.0, -6.5, -105.0), Vector3(50.0, 10.0, 300.0))
	k.scatter_trees(14.0, -245.0, -1.5, 10.0, 48.0, 120)
	for i in 7:
		k.snowman(Vector3((-1.0 if i % 2 == 0 else 1.0) * 10.0, -1.5, -20.0 - i * 32.0), (PI / 2.0) * (1.0 if i % 2 == 0 else -1.0))
	k.mountains(-110.0)
	return k.info


# =============================================================== LEVEL 7 (boss)
static func _brewmaster(root: Node3D) -> Dictionary:
	var theme: Dictionary = THEMES.brewery
	var k := Kit.new(root, theme)
	k.info.title = NAMES[8]
	k.info.theme = theme
	k.info.start = Vector3(0, 0.05, 6)
	k.info.kill_y = -10.0

	# the arena: a wooden floor inside a brick brewery hall. A barrel fence closes the south end.
	k.ground(0, 0, 26, -28, 20, 8.0, "wood")
	k.tunnel(26.0, -28.0)
	k.fence(10.5)
	k.boss(Vector3(0, 0, -14))

	# dressing: copper vats against the far wall, barrels along the sides
	for x in [-7.0, 0.0, 7.0]:
		k.vat(Vector3(x, 0.0, -27.0), 1.5, 8.0)
	for side in [-1.0, 1.0]:
		for i in 6:
			k.barrel(Vector3(side * 10.6, 0.0, 4.0 - i * 5.0), 1.0)
		k.barrel(Vector3(side * 10.6, 1.3, -1.0), 0.9)
	# a few beers to grab while you wait for your chance
	k.fruit_line(Vector3(-8.5, 0.7, 7), Vector3(-8.5, 0.7, -6), 6)
	k.fruit_line(Vector3(8.5, 0.7, 7), Vector3(8.5, 0.7, -6), 6)
	k.fruit_arc(Vector3(-4, 0.8, 8), Vector3(4, 0.8, 8), 7, 2.4)
	return k.info


# =============================================================== LEVEL 3 (boss: Don Humo)
static func _cigar_lounge(root: Node3D) -> Dictionary:
	var theme: Dictionary = THEMES.lounge
	var k := Kit.new(root, theme)
	k.info.title = NAMES[2]
	k.info.theme = theme
	k.info.start = Vector3(0, 0.05, 6)
	k.info.kill_y = -10.0

	# a smoky cigar lounge: red carpet, mahogany panelling, a row of sofas closing the south end
	k.ground(0, 0, 26, -28, 20, 8.0, "carpet")
	k.tunnel(26.0, -28.0, false)
	k.fence(10.5, 22.0, "sofas")
	k.cigar_boss(Vector3(0, 0, -14))

	k.bar(-27.0)
	for side in [-1.0, 1.0]:
		for i in 4:
			k.armchair(Vector3(side * 10.2, 0.0, 3.0 - i * 6.5), side * -PI * 0.5)
	for x in [-8.5, 8.5]:
		k.ashtray(Vector3(x, 0.0, -23.5), 1.2)
	k.ashtray(Vector3(-9.2, 0.0, 8.0), 0.9)
	k.ashtray(Vector3(9.2, 0.0, 8.0), 0.9)
	# a few beers to grab while you wait for your chance
	k.fruit_line(Vector3(-8.5, 0.7, 7), Vector3(-8.5, 0.7, -6), 6)
	k.fruit_line(Vector3(8.5, 0.7, 7), Vector3(8.5, 0.7, -6), 6)
	k.fruit_arc(Vector3(-4, 0.8, 8), Vector3(4, 0.8, 8), 7, 2.4)
	return k.info


# =============================================================== LEVEL 8 (plane)
static func _sky_run(root: Node3D) -> Dictionary:
	var theme: Dictionary = THEMES.sky
	var k := Kit.new(root, theme)
	k.info.title = NAMES[7]
	k.info.theme = theme
	k.info.start = Vector3(0, 9, 0)
	k.info.kill_y = -80.0
	k.info.flight = true
	k.info.fov = 70.0
	k.info.camera_offset = Vector3(0, 3.6, 12.5)
	k.info.camera_look = Vector3(0, 0.8, -14.0)

	# --- 1: open sky - floating rocks and seagulls, easy to get the feel of it
	for r in [[-9, 8, -60, 3.0], [9, 11, -85, 3.4], [-4, 5, -112, 3.0], [11, 6, -135, 3.2], [0, 15, -160, 3.5]]:
		k.fly("rock", Vector3(r[0], r[1], r[2]), {"radius": r[3]})
	k.fly("bird", Vector3(0, 9, -100), {"radius": 1.1, "amp": 9.0, "speed": 1.4})
	k.fly("bird", Vector3(0, 12, -150), {"radius": 1.1, "amp": 10.0, "speed": 1.1, "phase": 2.0})
	k.fly_beers(Vector3(0, 9, -25), Vector3(0, 9, -55), 8)
	k.fly_beers(Vector3(3, 9, -66), Vector3(-2, 12, -100), 9, 1.5)
	k.fly_beers(Vector3(-6, 10, -118), Vector3(6, 10, -150), 9, 2.0)
	k.fly_ring(Vector3(0, 9, -185))

	# --- 2: balloon forest - slalom between hot-air balloons
	for b in [[-7, 10, -215], [7, 7, -232], [-3, 13, -250], [8, 12, -268], [-10, 6, -285], [2, 9, -300], [10, 9, -318], [-6, 12, -335], [0, 5, -348]]:
		k.fly("balloon", Vector3(b[0], b[1], b[2]), {"radius": 3.2, "phase": float(b[2]) * 0.1})
	k.fly("bird", Vector3(0, 8, -260), {"radius": 1.1, "amp": 8.0, "speed": 1.7})
	k.fly("bird", Vector3(0, 11, -325), {"radius": 1.1, "amp": 9.0, "speed": 1.3, "phase": 1.0})
	k.fly_beers(Vector3(0, 9, -200), Vector3(0, 9, -226), 7)
	k.fly_beers(Vector3(-2, 9, -240), Vector3(3, 10, -295), 10, 1.0)
	k.fly_beers(Vector3(5, 9, -305), Vector3(-4, 9, -340), 8, 1.0)
	k.fly_ring(Vector3(0, 9, -375))

	# --- 3: storm front - four walls of thunderclouds, each with a gap in a different place
	k.storm_wall(-405, 0.0)
	k.storm_wall(-440, -8.0)
	k.storm_wall(-475, 8.0)
	k.storm_wall(-510, 0.0)
	k.fly_beers(Vector3(0, 9, -385), Vector3(0, 9, -400), 4)
	k.fly_beers(Vector3(-1, 9, -412), Vector3(-8, 9, -434), 5)
	k.fly_beers(Vector3(-8, 9, -446), Vector3(8, 9, -469), 7)
	k.fly_beers(Vector3(8, 9, -481), Vector3(0, 9, -504), 6)
	k.fly_ring(Vector3(0, 9, -560))

	# --- 4: windmill valley - towers with spinning blades (fly between, or over the top)
	for w in [[-8, 11, -575], [7, 8, -595], [0, 13, -615], [-10, 10, -635], [9, 12, -650], [-3, 7, -670]]:
		k.fly("tower", Vector3(w[0], 0, w[2]), {"radius": 1.7, "height": float(w[1]), "bar_len": 5.5, "speed": 1.6 if w[0] < 0 else -1.4})
	k.fly("gate", Vector3(0, 10, -690), {"bar_len": 9.0, "speed": 1.2})
	k.fly_beers(Vector3(0, 9, -565), Vector3(0, 9, -585), 5)
	k.fly_beers(Vector3(3, 9, -600), Vector3(-5, 14, -640), 9, 1.5)
	k.fly_beers(Vector3(5, 14, -648), Vector3(0, 10, -680), 6)

	# --- 5: Don Humo's blimps and the final propeller gate
	for b in [[-5, 6, -715], [6, 13, -735], [0, 9, -752]]:
		k.fly("blimp", Vector3(b[0], b[1], b[2]), {"radius": 2.3, "half_len": 7.0})
	k.fly("gate", Vector3(0, 9, -775), {"bar_len": 10.0, "speed": -1.5, "phase": 1.0})
	k.fly("bird", Vector3(0, 12, -705), {"radius": 1.1, "amp": 10.0, "speed": 1.6})
	k.fly_beers(Vector3(0, 9, -700), Vector3(-6, 10, -712), 4)
	k.fly_beers(Vector3(0, 10, -722), Vector3(0, 12, -748), 7, 1.0)
	k.fly_goal(Vector3(0, 9, -810))

	# --- the sky: a sea of clouds below, clouds and far peaks around
	k.water(-10.0, -400.0, 1000.0)
	k.sky_decor(40.0, -860.0)
	return k.info
