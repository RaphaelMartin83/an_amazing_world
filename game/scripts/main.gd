extends Node3D
# Game flow: title -> playing -> level complete -> next level / the end. Owns the level, player and camera.

const Levels = preload("res://scripts/levels.gd")
const Player = preload("res://scripts/player.gd")
const CameraRig = preload("res://scripts/camera_rig.gd")
const Hud = preload("res://scripts/hud.gd")
const FaceIcon = preload("res://scripts/face_icon.gd")
const FriendConfig = preload("res://scripts/friend_config.gd")

var level_root: Node3D
var player: CharacterBody3D
var cam_rig: Node3D
var hud: CanvasLayer
var info: Dictionary
var level_index := 0
var state := "title"
var boulder: Node3D
var spawn_pos := Vector3.ZERO
var face_vp: SubViewport
var selected_level := 0
const COUNT_FOR_TESTS := Levels.COUNT


func _ready() -> void:
	Game.hero = FriendConfig.HERO
	_make_face_viewport()
	hud = Hud.new()
	hud.level_count = Levels.COUNT
	add_child(hud)
	Game.message.connect(hud.show_message)
	Game.level_completed.connect(_on_level_completed)
	hud.level_requested.connect(_jump_to_level)
	# `--level=N` on the command line starts straight in level N (e.g. AnAmazingWorld.exe -- --level=3)
	var start_level := _level_from_args()
	selected_level = maxi(start_level, 0)
	load_level(selected_level)
	if start_level >= 0:
		_start_playing()
	else:
		_show_title()
	if "--selftest" in OS.get_cmdline_user_args() or "--shots" in OS.get_cmdline_user_args():
		var dev := preload("res://scripts/dev/selftest.gd").new()
		dev.main = self
		add_child(dev)


func _make_face_viewport() -> void:
	face_vp = SubViewport.new()
	face_vp.size = Vector2i(160, 160)
	face_vp.transparent_bg = true
	face_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var icon := FaceIcon.new()
	icon.cfg = Game.hero
	icon.size = Vector2(160, 160)
	face_vp.add_child(icon)
	add_child(face_vp)
	Game.face_texture = face_vp.get_texture()


func _level_from_args() -> int:
	for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			var n := int(a.get_slice("=", 1))
			if n >= 1 and n <= Levels.COUNT:
				return n - 1
	return -1


# Title-screen level picker: loads the level behind the title so you see what you're choosing.
func _select_level(idx: int) -> void:
	idx = posmod(idx, Levels.COUNT)
	if idx == selected_level and state == "title" and level_root:
		_show_title()
		return
	selected_level = idx
	load_level(idx)
	_show_title()
	Sfx.play("fruit")


# Used by the pause menu: restart the run at the chosen level.
func _jump_to_level(idx: int) -> void:
	Game.reset_run()
	hud.fade_to(0.0, 0.1)
	hud.hide_screen()
	selected_level = idx
	load_level(idx)
	_start_playing()


func _unhandled_input(event: InputEvent) -> void:
	if state == "title" and event is InputEventKey and event.pressed and not event.echo:
		var idx: int = int(event.physical_keycode) - KEY_1
		if idx >= 0 and idx < Levels.COUNT:
			_select_level(idx)


func _show_title() -> void:
	state = "title"
	var hero_name := str(Game.hero.name)
	hud.show_screen("AN AMAZING WORLD", "starring  %s" % hero_name,
		"Move: WASD / arrows / left stick     Jump: Space / A  (press again in the air = double jump)\n" +
		"FART ATTACK: J / X / mouse click / X-button     Slide: C / Ctrl / B  (jump out of it = long jump)\n" +
		"Slide in mid-air = body slam     Esc: pause     R: restart level",
		"<   %s   >     (A / D or 1-%d to pick a level)\n- press ENTER to start -" % [Levels.NAMES[selected_level], Levels.COUNT])
	if player:
		player.controls_enabled = false


func load_level(idx: int) -> void:
	level_index = idx
	if level_root:
		remove_child(level_root)
		level_root.queue_free()
	Game.boss_hide.emit()
	level_root = Node3D.new()
	level_root.name = "Level"
	add_child(level_root)
	Game.reset_level()
	info = Levels.build(idx, level_root)
	_make_environment(info.theme)

	player = Player.new()
	player.name = "Player"
	spawn_pos = info.start
	player.position = spawn_pos
	level_root.add_child(player)
	player.died.connect(_on_player_died)
	Game.player = player
	Game.kill_y = info.kill_y

	cam_rig = CameraRig.new()
	cam_rig.target = player
	cam_rig.offset = info.camera_offset
	cam_rig.look_offset = info.camera_look
	level_root.add_child(cam_rig)
	cam_rig.snap()
	if info.theme.get("snow", false):
		_add_snowfall()

	boulder = info.boulder
	var total := 0
	for c in get_tree().get_nodes_in_group("crate"):
		if c.counts_for_total:
			total += 1
	Game.crates_total = total
	Game.gems_total = get_tree().get_nodes_in_group("gem").size()
	Game.changed.emit()


# Falling snow that follows the camera.
func _add_snowfall() -> void:
	var p := CPUParticles3D.new()
	var flake := SphereMesh.new()
	flake.radius = 0.07
	flake.height = 0.14
	flake.radial_segments = 6
	flake.rings = 3
	p.mesh = flake
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 1, 1, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p.material_override = m
	p.amount = 800
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(26.0, 0.5, 26.0)
	p.position = Vector3(0, 12.0, -10.0)
	p.direction = Vector3(0, -1, 0)
	p.spread = 15.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.2
	p.gravity = Vector3(-0.5, -2.2, 0.4)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.5
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cam_rig.camera.add_child(p)


func _make_environment(theme: Dictionary) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = theme.sky_top
	psm.sky_horizon_color = theme.sky_horizon
	psm.ground_horizon_color = theme.ground_horizon
	psm.ground_bottom_color = theme.ground_bottom
	psm.sun_angle_max = 30.0
	psm.sky_curve = 0.25
	sky.sky_material = psm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = theme.ambient
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.0
	env.fog_enabled = true
	env.fog_light_color = theme.fog
	env.fog_density = theme.fog_density
	env.fog_sky_affect = 0.4
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.22
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	level_root.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = theme.sun_rot
	sun.light_color = theme.sun_color
	sun.light_energy = theme.sun_energy
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.shadow_blur = 1.4
	level_root.add_child(sun)


func _process(_delta: float) -> void:
	match state:
		"title":
			if Input.is_action_just_pressed("confirm"):
				_start_playing()
			elif Input.is_action_just_pressed("move_left"):
				_select_level(selected_level - 1)
			elif Input.is_action_just_pressed("move_right"):
				_select_level(selected_level + 1)
		"complete_wait":
			if Input.is_action_just_pressed("confirm"):
				_next_level()
		"gameover":
			if Input.is_action_just_pressed("confirm"):
				_restart_run()
		"playing":
			if Input.is_action_just_pressed("restart"):
				_restart_level()
			if boulder and not boulder.active and player.global_position.distance_to(spawn_pos) > 1.2:
				boulder.active = true
				Sfx.play("rumble")


func _start_playing() -> void:
	hud.hide_screen()
	state = "playing"
	player.controls_enabled = true
	hud.show_banner(str(info.title))
	if info.get("boss") != null:
		info.boss.activate()


func _on_player_died() -> void:
	if state != "playing":
		return
	Game.lives -= 1
	Game.changed.emit()
	if Game.lives <= 0:
		state = "gameover"
		hud.fade_to(0.55, 0.6)
		hud.show_screen("GAME OVER", "", "beers: %d   crates: %d / %d" % [Game.fruit, Game.crates_broken, Game.crates_total], "- press ENTER to try again -")
		return
	var lvl := level_index
	hud.fade_to(1.0, 0.25)
	await get_tree().create_timer(0.35).timeout
	if lvl != level_index or state != "playing":
		return
	_respawn()
	hud.fade_to(0.0, 0.35)


func _respawn() -> void:
	var pos: Vector3 = spawn_pos
	if Game.checkpoint != null:
		pos = Game.checkpoint + Vector3(0, 0.05, 0)
	player.respawn(pos)
	player.controls_enabled = true
	cam_rig.snap()
	if boulder:
		boulder.reset_to(pos.z - 22.0)
	if info.get("boss") != null and is_instance_valid(info.boss):
		info.boss.reset_fight()


func _restart_level() -> void:
	player.die()


func _on_level_completed() -> void:
	if state != "playing":
		return
	state = "complete"
	Sfx.play("win")
	await get_tree().create_timer(1.8).timeout
	if state != "complete":
		return
	var last := level_index >= Levels.COUNT - 1
	var stats := "beers: %d     crates: %d / %d     lives: %d" % [Game.fruit, Game.crates_broken, Game.crates_total, Game.lives]
	if last:
		hud.show_screen("THE END", "thanks for playing, %s!" % str(Game.hero.name), stats, "- press ENTER to play again -")
	else:
		hud.show_screen("LEVEL COMPLETE!", str(info.title), stats, "- press ENTER for the next level -")
	state = "complete_wait"


func _next_level() -> void:
	var last := level_index >= Levels.COUNT - 1
	hud.hide_screen()
	if last:
		Game.reset_run()
		load_level(0)
	else:
		load_level(level_index + 1)
	_start_playing()


func _restart_run() -> void:
	hud.fade_to(0.0, 0.3)
	hud.hide_screen()
	Game.reset_run()
	load_level(level_index)
	_start_playing()
