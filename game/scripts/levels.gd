extends RefCounted
# Level definitions. Each builds into a Node3D root and returns the info dictionary.

const Kit = preload("res://scripts/level_kit.gd")

const COUNT := 2

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
		_:
			return _boulder_rush(root)


# =============================================================== LEVEL 1
static func _jungle_run(root: Node3D) -> Dictionary:
	var theme: Dictionary = THEMES.jungle
	var k := Kit.new(root, theme)
	k.info.title = "1. JUNGLE RUN"
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
	k.info.title = "2. BOULDER RUSH"
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
