extends Node

const Levels = preload("res://scripts/levels.gd")
# Developer harness (not used in normal play).
#   --selftest : mechanics checks + a scripted bot that plays every level, prints a report, exits non-zero on failure
#   --shots    : saves screenshots (needs a renderer, e.g. xvfb + software Vulkan) to res://../build/shots

var main: Node
var held := {}
var taps: Array[String] = []
var tap_timer := {}
var TRACE := false
var failures := 0
var deaths := 0
var death_log: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	if "--shots" in OS.get_cmdline_user_args():
		await _shots()
	else:
		await _selftest()
	get_tree().quit(1 if failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


# ------------------------------------------------------------------ input helpers

func _hold(action: String, strength: float) -> void:
	if strength > 0.01:
		if not held.has(action) or absf(held[action] - strength) > 0.01:
			Input.action_press(action, strength)
			held[action] = strength
	elif held.has(action):
		Input.action_release(action)
		held.erase(action)


func _tap(action: String, hold := 3) -> void:
	if tap_timer.has(action):
		return
	Input.action_press(action)
	tap_timer[action] = hold
	taps.append(action)


# Taps last 3 frames, then the action is forced released for 3 frames so the game sees a fresh press each time.
func _tick_taps() -> void:
	for a in tap_timer.keys():
		var v: int = tap_timer[a]
		if v > 0:
			v -= 1
			if v == 0:
				Input.action_release(a)
				v = -3
		else:
			v += 1
			if v == 0:
				tap_timer.erase(a)
				continue
		tap_timer[a] = v


func _release_taps() -> void:
	for a in taps:
		Input.action_release(a)
	taps.clear()
	tap_timer.clear()


func _release_all() -> void:
	_release_taps()
	for a in held.keys():
		Input.action_release(a)
	held.clear()


# ------------------------------------------------------------------ tests

func _selftest() -> void:
	print("== level select")
	main._show_title()
	main._select_level(Levels.idx("sewer"))
	_check(main.level_index == Levels.idx("sewer") and main.state == "title", "title screen: picking the sewer loads it")
	main._select_level(main.COUNT_FOR_TESTS - 1)
	main._select_level(main.selected_level + 1)
	_check(main.level_index == 0, "title screen: next level after the last wraps around to 1")
	main.hud.level_requested.emit(1)
	await frames(2)
	_check(main.level_index == 1 and main.state == "playing", "pause menu: jumping to level 2 starts it")
	_check(main._level_from_args() == -1, "no --level argument by default")
	print("== mechanics")
	main.load_level(0)
	main._start_playing()
	var p: CharacterBody3D = main.player
	await frames(40)
	_check(p.is_on_floor(), "player lands and stands on the floor")
	var y0 := p.global_position.y
	_tap("jump")
	await frames(2)
	_release_taps()
	await frames(10)
	_check(p.global_position.y > y0 + 0.6, "jump leaves the ground (y +%.2f)" % (p.global_position.y - y0))
	await frames(60)
	_check(p.is_on_floor(), "player comes back down")

	var z0 := p.global_position.z
	_hold("move_forward", 1.0)
	await frames(60)
	_hold("move_forward", 0.0)
	_check(z0 - p.global_position.z > 5.0, "holding forward runs along -Z (%.1f m in 1 s)" % (z0 - p.global_position.z))
	await frames(30)

	p.respawn(Vector3(0, 0.05, -7.6))
	await frames(10)
	var before := Game.crates_broken
	var fruit_before := Game.fruit
	_tap("spin")
	await frames(3)
	_release_taps()
	await frames(10)
	_check(Game.crates_broken == before + 1, "fart attack breaks the crate in front")
	_check(Game.fruit == fruit_before + 1, "breaking a crate gives a beer")

	# jump on a crate
	p.respawn(Vector3(2.5, 3.0, -9.0))
	await frames(40)
	_check(Game.crates_broken == before + 2, "landing on a crate breaks it")

	# bounce crate: hold jump while landing on it -> reach the gem above
	var gems0 := Game.gems
	_hold("jump", 1.0)
	p.respawn(Vector3(3.2, 4.0, -17.0))
	p.invuln = 0.0
	await frames(70)
	_hold("jump", 0.0)
	_check(Game.gems == gems0 + 1, "bouncing high on a bounce crate collects the gem above it")

	# TNT: explodes after the fuse, spawns the explosion effect and hurts a nearby hero
	main.load_level(0)
	main._start_playing()
	p = main.player
	await frames(30)
	var tnt: Node3D = preload("res://scripts/crate.gd").new()
	main.level_root.add_child(tnt)
	tnt.setup("boom")
	tnt.position = Vector3(0, 0.5, -3.0)
	p.respawn(Vector3(0, 0.05, -1.5))
	p.invuln = 0.0
	p.model.flash = 0.0
	tnt.hit(null, "spin")
	await frames(3 * 60 + 20)
	var fx := 0
	for c in main.level_root.get_children():
		if c.get_script() == preload("res://scripts/explosion.gd"):
			fx += 1
	_check(fx == 1, "TNT spawns an explosion effect")
	_check(p.dead, "TNT explosion hurts a hero standing next to it")
	_check(not is_instance_valid(tnt) or tnt.broken, "TNT crate is gone after exploding")

	print("== slide / slam edge cases")
	main.load_level(0)
	main._start_playing()
	p = main.player
	await frames(30)
	var stuck := 0
	for delay in range(0, 22):
		p.respawn(Vector3(0, 0.55, -3.0))     # drops ~0.55 m; slide is tapped at every moment around the landing
		await frames(delay)
		_tap("slide")
		await frames(3)
		_release_taps()
		await frames(50)
		if p.slamming or p.slam_recover > 0.0 or p.slide_t > 0.0:
			stuck += 1
		else:
			_hold("move_forward", 1.0)
			var zz := p.global_position.z
			await frames(20)
			_hold("move_forward", 0.0)
			if zz - p.global_position.z < 1.5:
				stuck += 1
	_check(stuck == 0, "pressing slide at any moment around a landing never leaves him stuck (%d stuck of 22)" % stuck)

	print("== beers and puking")
	main.load_level(0)
	main._start_playing()
	p = main.player
	await frames(30)
	var lives_before := Game.lives
	Game.fruit = 98
	Game.add_fruit(1)
	_check(Game.fruit == 99 and p.puke_t <= 0.0, "99 beers: no puking yet")
	Game.add_fruit(1)
	await frames(4)
	_check(Game.fruit == 0 and Game.lives == lives_before + 1, "100 beers: counter resets and he gets an extra life")
	_check(p.puke_t > 0.0, "100 beers: Palmouze pukes")
	await frames(20)
	_check(p.model.puke_green > 0.2, "100 beers: his face turns green")
	# he keeps full control while puking: run, jump, fart
	var pz := p.global_position.z
	_hold("move_forward", 1.0)
	_tap("jump", 15)
	await frames(18)
	_check(p.puke_t > 0.0 and not p.is_on_floor(), "he can jump while puking")
	await frames(30)
	_check(pz - p.global_position.z > 3.0, "he can run while puking (%.1f m)" % (pz - p.global_position.z))
	_release_taps()
	_hold("move_forward", 0.0)
	await frames(20)
	var gb := Game.crates_broken
	p.respawn(Vector3(0, 0.05, -7.6))   # right behind the crate row
	await frames(10)
	Game.fruit = 99
	Game.add_fruit(1)
	_tap("spin")
	await frames(3)
	_release_taps()
	await frames(10)
	_check(p.puke_t > 0.0 and Game.crates_broken == gb + 1, "he can fart-attack while puking")
	await frames(110)
	_check(p.puke_t <= 0.0 and not p.dead and p.model.puke_green < 0.05, "the puke ends and he is back to normal")
	var puddles := 0
	for c in main.level_root.get_children():
		if c is Node3D and c.get_child_count() == 7 and c.get_child(0) is MeshInstance3D:
			puddles += 1
	_check(puddles >= 1, "a puddle is left on the floor")

	print("== new mechanics")
	main.load_level(Levels.idx("city"))
	main._start_playing()
	p = main.player
	await frames(30)
	p.respawn(Vector3(0, 0.1, -53.6))   # standing on the start of the conveyor belt (it pushes towards -Z, forward)
	await frames(10)
	var cz0 := p.global_position.z
	await frames(40)
	var carried := cz0 - p.global_position.z
	_check(carried > 2.0, "conveyor belt carries the hero forward, away from the camera (%.1f m in 0.67 s)" % carried)
	p.respawn(Vector3(0, 0.1, -53.6))
	await frames(10)
	cz0 = p.global_position.z
	_hold("move_forward", 1.0)
	await frames(40)
	_hold("move_forward", 0.0)
	var on_belt := cz0 - p.global_position.z
	p.respawn(Vector3(0, 0.1, -22.0))   # plain ground
	await frames(10)
	cz0 = p.global_position.z
	_hold("move_forward", 1.0)
	await frames(40)
	_hold("move_forward", 0.0)
	var on_ground := cz0 - p.global_position.z
	_check(on_belt > on_ground + 2.0, "running with the belt is faster (%.1f m vs %.1f m on plain ground)" % [on_belt, on_ground])
	main.load_level(Levels.idx("snow"))
	main._start_playing()
	p = main.player
	await frames(30)
	p.respawn(Vector3(0, 0.1, -20.0))   # on ice
	await frames(15)
	_hold("move_forward", 1.0)
	await frames(60)
	_hold("move_forward", 0.0)
	await frames(8)
	var ice_speed := Vector2(p.velocity.x, p.velocity.z).length()
	p.respawn(Vector3(0, 0.1, -5.0))    # on plain snow
	await frames(15)
	_hold("move_forward", 1.0)
	await frames(60)
	_hold("move_forward", 0.0)
	await frames(8)
	var snow_speed := Vector2(p.velocity.x, p.velocity.z).length()
	_check(ice_speed > 4.0 and snow_speed < 1.0, "ice is slippery (still moving at %.1f m/s vs %.1f on snow)" % [ice_speed, snow_speed])
	main.load_level(Levels.idx("beach"))
	main._start_playing()
	p = main.player
	await frames(30)
	var wv: Node3D = get_tree().get_nodes_in_group("wave")[0]
	p.respawn(Vector3(0, 0.05, wv.global_position.z))
	p.invuln = 0.0
	p.model.flash = 0.0
	wv.t = 2.4 + 1.0 + 0.35 + 0.1     # mid-surge
	await frames(6)
	_check(p.dead, "a tidal wave at full height hurts the hero")
	main.load_level(Levels.idx("beach"))
	main._start_playing()
	p = main.player
	await frames(30)
	wv = get_tree().get_nodes_in_group("wave")[0]
	p.respawn(Vector3(0, 0.05, wv.global_position.z))
	p.invuln = 0.0
	p.model.flash = 0.0
	wv.t = 0.3                          # calm
	await frames(20)
	_check(not p.dead, "the same spot is safe while the water is calm")

	print("== boss: the Brewmaster")
	await _boss_tests()

	print("== boss: Don Humo (the cigar)")
	await _cigar_tests()

	print("== credits")
	await _credits_tests()

	print("== bot plays level 1 (Jungle Run)")
	await _play(0, 150.0)
	print("== bot plays level 2 (Boulder Rush)")
	await _play(1, 150.0)
	print("== bot plays the sewer")
	await _play(Levels.idx("sewer"), 150.0)
	print("== bot plays the city")
	await _play(Levels.idx("city"), 200.0)
	print("== bot plays the beach")
	await _play(Levels.idx("beach"), 200.0)
	print("== bot plays the snow level")
	await _play(Levels.idx("snow"), 200.0)
	print("== result: %s (%d failures)" % ["OK" if failures == 0 else "FAILED", failures])


func _play(idx: int, timeout_s: float) -> void:
	Game.reset_run()
	main.load_level(idx)
	main._start_playing()
	var dir := Vector3(0, 0, 1) if idx == 1 else Vector3(0, 0, -1)
	var lives0 := Game.lives
	deaths = 0
	death_log.clear()
	var t := 0.0
	var last_dead := false
	while main.state == "playing" and t < timeout_s:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		var pl: Node3D = main.player
		if pl.dead and not last_dead:
			deaths += 1
			death_log.append("%s@(%.0f, %.1f, %.0f)" % [pl.death_reason, pl.global_position.x, pl.global_position.y, pl.global_position.z])
		last_dead = pl.dead
		if int(t * 60.0) % 300 == 0:
			print("    t=%.0f pos=%s vel=%s floor=%s ctrl=%s" % [t, str(pl.global_position.snapped(Vector3.ONE * 0.1)), str(pl.velocity.snapped(Vector3.ONE * 0.1)), str(pl.is_on_floor()), str(pl.controls_enabled)])
		_bot_step(dir)
	_release_all()
	var done: bool = main.state == "complete" or main.state == "complete_wait"
	print("  finished=%s  time=%.1fs  deaths=%d %s  beers=%d  crates=%d/%d" % [str(done), t, deaths, str(death_log), Game.fruit, Game.crates_broken, Game.crates_total])
	_check(done, "%s is completable by the bot" % Levels.NAMES[idx])
	await frames(5)
	if main.state != "complete_wait" and main.state != "complete":
		return
	main.state = "playing"  # allow the next load


func _floor_at(point: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = main.player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(point + Vector3(0, 3.0, 0), point + Vector3(0, -3.0, 0), 1)
	return not space.intersect_ray(q).is_empty()


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = main.player.get_world_3d().direct_space_state
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))


func _bot_step(dir: Vector3) -> void:
	_tick_taps()
	var p: CharacterBody3D = main.player
	if p.dead or not p.controls_enabled:
		_hold("move_forward", 0.0)
		_hold("move_back", 0.0)
		return
	var pos := p.global_position
	var on_floor := p.is_on_floor()
	var go := 1.0
	var jump := false
	var spin := false

	# gap ahead?
	if on_floor and not _floor_at(pos + dir * 0.9):
		var landing := false
		for d in [2.5, 3.5, 4.5, 5.5, 6.5, 7.5, 8.5]:
			if _floor_at(pos + dir * d):
				landing = true
				break
		if landing:
			jump = true
		else:
			go = 0.0
	elif not on_floor and p.velocity.y < -2.0 and p.air_jumps > 0 and pos.y < p.last_floor_y + 0.4 and not _floor_at(pos + dir * 0.8):
		jump = true  # rescue double jump when sinking into a gap

	# obstacle in front
	if on_floor:
		var hit := _ray(pos + Vector3(0, 0.45, 0), pos + Vector3(0, 0.45, 0) + dir * 1.6)
		if not hit.is_empty():
			var c: Object = hit.collider
			if c.is_in_group("crate") and c.kind != "iron" and c.kind != "boom":
				spin = true
			else:
				jump = true

	# enemies
	for e in get_tree().get_nodes_in_group("enemy"):
		var d: Vector3 = e.global_position - pos
		if Vector2(d.x, d.z).length() < 2.4 and absf(d.y) < 1.5:
			spin = true

	# spinners: wait for the bar to be roughly across the path, then run through with a jump
	for s in get_tree().get_nodes_in_group("spinner"):
		var ahead: float = (s.global_position - pos).dot(dir)
		if ahead > 0.0 and ahead < 9.0:
			var bar := Vector2(cos(s.rotation.y), -sin(s.rotation.y))   # bar direction (x, z)
			var along_path := absf(bar.dot(Vector2(dir.x, dir.z)))
			if ahead > 3.2 and along_path > 0.45:
				go = 0.0 if ahead < 5.5 else go
			if ahead < 2.6 and ahead > 1.2 and on_floor:
				jump = true

	if TRACE and pos.z < -122.0 and pos.z > -140.0:
		var ms := ""
		for m in get_tree().get_nodes_in_group("mover"):
			ms += " m(%.1f,%.1f,%.1f)" % [m.global_position.x, m.global_position.y, m.global_position.z]
		print("      x=%.2f z=%.2f y=%.2f vy=%.1f vx=%.1f floor=%s jump=%s airj=%d go=%.0f %s" % [pos.x, pos.z, pos.y, p.velocity.y, p.velocity.x, str(on_floor), str(jump), p.air_jumps, go, ms])
	# tidal waves: wait until there is enough calm left to run across
	for w in get_tree().get_nodes_in_group("wave"):
		var wa: float = (w.global_position - pos).dot(dir)
		if wa > 2.6 and wa < 9.0 and not w.is_safe():
			go = 0.0

	# steer to the middle of the path (or towards the next moving platform)
	var tx := 0.0
	var best := 99.0
	for m in get_tree().get_nodes_in_group("mover"):
		var ahead_m: float = (m.global_position - pos).dot(dir)
		if ahead_m > 1.8 and ahead_m < 14.0 and ahead_m < best:
			best = ahead_m
			tx = m.global_position.x
	var ix := clampf((tx - pos.x) * 1.4, -1.0, 1.0)
	_hold("move_right", maxf(ix, 0.0))
	_hold("move_left", maxf(-ix, 0.0))
	_hold("move_forward", go if dir.z < 0 else 0.0)
	_hold("move_back", go if dir.z > 0 else 0.0)
	if jump:
		_tap("jump", 15)
	if spin:
		_tap("spin")


# ------------------------------------------------------------------ screenshots

func _shots() -> void:
	var out := ProjectSettings.globalize_path("res://").path_join("../build/shots")
	DirAccess.make_dir_recursive_absolute(out)
	var spots := [
		[0, "L1_start", Vector3(0, 0.05, -1), 0],
		[0, "L1_crates", Vector3(0, 0.05, -14), 0],
		[0, "L1_bridge", Vector3(0, 0.05, -66), 0],
		[0, "L1_plaza", Vector3(0, 0.05, -97), 0],
		[0, "L1_movers", Vector3(0, 0.05, -120), 0],
		[0, "L1_spinners", Vector3(0, 0.05, -160), 0],
		[0, "L1_spinner_close", Vector3(0, 0.05, -163), 0],
		[0, "L1_goal", Vector3(0, 3.05, -203), 0],
		[1, "L2_start", Vector3(0, 0.05, -92), 1],
		[1, "L2_mid", Vector3(0, 0.05, -30), 1],
		[1, "L2_causeway", Vector3(0, 0.05, 28), 1],
		[Levels.idx("sewer"), "L3_start", Vector3(0, 0.05, -1), 2],
		[Levels.idx("sewer"), "L3_crumble", Vector3(0, 0.05, -58), 2],
		[Levels.idx("sewer"), "L3_toys", Vector3(0, 0.05, -95), 2],
		[Levels.idx("sewer"), "L3_movers", Vector3(0, 0.05, -118), 2],
		[Levels.idx("sewer"), "L3_pump", Vector3(0, 0.05, -152), 2],
		[Levels.idx("city"), "L4_start", Vector3(0, 0.05, -1), 3],
		[Levels.idx("city"), "L4_conveyor", Vector3(0, 0.05, -47), 3],
		[Levels.idx("city"), "L4_stairs", Vector3(0, 0.05, -90), 3],
		[Levels.idx("city"), "L4_movers", Vector3(0, 2.65, -118), 3],
		[Levels.idx("city"), "L4_garden", Vector3(0, 2.65, -156), 3],
		[Levels.idx("city"), "L4_scaffold", Vector3(0, 2.65, -186), 3],
		[Levels.idx("beach"), "L5_start", Vector3(0, 0.05, -1), 4],
		[Levels.idx("beach"), "L5_boardwalk", Vector3(0, 0.05, -46), 4],
		[Levels.idx("beach"), "L5_rafts", Vector3(0, 0.05, -90), 4],
		[Levels.idx("beach"), "L5_wave", Vector3(0, 0.05, -122), 4],
		[Levels.idx("beach"), "L5_pier", Vector3(0, 0.05, -154), 4],
		[Levels.idx("snow"), "L6_start", Vector3(0, 0.05, -1), 5],
		[Levels.idx("snow"), "L6_ice", Vector3(0, 0.05, -16), 5],
		[Levels.idx("snow"), "L6_floes", Vector3(0, 0.05, -42), 5],
		[Levels.idx("snow"), "L6_rink", Vector3(0, 0.05, -96), 5],
		[Levels.idx("snow"), "L6_climb", Vector3(0, 1.35, -142), 5],
		[Levels.idx("snow"), "L6_summit", Vector3(0, 3.95, -180), 5],
	]
	if "--only=credits" in OS.get_cmdline_user_args():
		await _credits_shots(out)
		return
	main._select_level(1)
	await frames(30)
	_save(out, "title")
	await _belt_motion(out)
	await _boss_shots(out)
	await _cigar_shots(out)
	await _credits_shots(out)
	var cur := -1
	for s in spots:
		if cur != s[0]:
			main.load_level(s[0])
			main._start_playing()
			main.hud.hide_screen()
			main.hud.banner.modulate.a = 0.0
			cur = s[0]
			await frames(5)
		var p: CharacterBody3D = main.player
		p.respawn(s[2])
		p.invuln = 0.0
		p.model.flash = 0.0
		main.cam_rig.snap()
		if main.boulder:
			main.boulder.active = false
		if str(s[1]) == "L5_wave":
			for w in get_tree().get_nodes_in_group("wave"):
				w.t = 2.4 + 1.0 + 0.35 + 0.1
		await frames(50)
		main.cam_rig.snap()
		await frames(4)
		_save(out, s[1])
	# TNT: lit fuse, then the explosion at three moments
	main.load_level(0)
	main._start_playing()
	main.hud.hide_screen()
	main.hud.banner.modulate.a = 0.0
	main.player.respawn(Vector3(0, 0.05, -1))
	main.player.invuln = 0.0
	main.player.model.flash = 0.0
	main.cam_rig.snap()
	var tnt: Node3D = preload("res://scripts/crate.gd").new()
	main.level_root.add_child(tnt)
	tnt.setup("boom")
	tnt.position = Vector3(0, 0.5, -6.5)
	await frames(30)
	tnt.hit(null, "spin")
	await frames(50)
	_save(out, "boom_fuse")
	tnt.fuse = 0.02
	await frames(10)
	_save(out, "boom_1")
	await frames(10)
	_save(out, "boom_2")
	await frames(35)
	_save(out, "boom_3")
	# a bounce crate with its gem
	main.player.respawn(Vector3(0, 0.05, -12))
	main.player.invuln = 0.0
	main.player.model.flash = 0.0
	main.cam_rig.snap()
	await frames(40)
	main.cam_rig.camera.fov = 75
	await frames(5)
	_save(out, "bounce_gem")
	main.cam_rig.camera.fov = 62
	# beer bottle close-up and the puke
	main.player.respawn(Vector3(0, 0.05, -2))
	main.player.invuln = 0.0
	main.player.model.flash = 0.0
	main.cam_rig.snap()
	await frames(30)
	var bottle: Node3D = preload("res://scripts/fruit.gd").new()
	main.level_root.add_child(bottle)
	bottle.set_physics_process(false)    # keep the player's magnet from collecting it
	bottle.global_position = main.player.global_position + Vector3(1.2, 1.5, 1.0)
	var bcam := Camera3D.new()
	main.level_root.add_child(bcam)
	bcam.fov = 40
	bcam.look_at_from_position(bottle.global_position + Vector3(0.0, 0.1, 1.6), bottle.global_position, Vector3.UP)
	bcam.current = true
	main.hud.visible = false
	await frames(14)
	_save(out, "bottle")
	if is_instance_valid(bottle):
		bottle.queue_free()
	bcam.queue_free()
	main.hud.visible = true
	Game.fruit = 99
	Game.add_fruit(1)
	main.cam_rig.camera.current = true
	await frames(22)
	_save(out, "puke_1")
	await frames(14)
	_save(out, "puke_2")
	var scam := Camera3D.new()
	main.level_root.add_child(scam)
	scam.fov = 45
	var sp: Vector3 = main.player.global_position
	scam.look_at_from_position(sp + Vector3(5.5, 1.7, -1.5), sp + Vector3(0, 1.0, -1.8), Vector3.UP)
	scam.current = true
	main.hud.visible = false
	await frames(2)
	_save(out, "puke_side")
	scam.queue_free()
	main.cam_rig.camera.current = true
	main.hud.visible = true
	await frames(30)
	_save(out, "puke_3")
	await frames(40)
	main.player.respawn(Vector3(0, 0.05, -2))
	main.player.invuln = 0.0
	main.player.model.flash = 0.0
	main.cam_rig.snap()
	await frames(20)
	_hold("move_forward", 1.0)
	await frames(10)
	Game.fruit = 99
	Game.add_fruit(1)
	await frames(28)
	_save(out, "puke_run")
	_hold("move_forward", 0.0)
	await frames(60)

	# the fart attack, mid-twirl
	main.load_level(0)
	main._start_playing()
	main.hud.hide_screen()
	main.hud.banner.modulate.a = 0.0
	main.player.respawn(Vector3(0, 0.05, -4))
	main.player.invuln = 0.0
	main.player.model.flash = 0.0
	main.cam_rig.snap()
	await frames(40)
	_tap("spin")
	await frames(14)
	_save(out, "fart")
	_release_taps()
	await frames(20)
	_save(out, "fart_cloud")
	# close-up of the hero's face and body
	main.load_level(0)
	main._start_playing()
	main.hud.hide_screen()
	await frames(30)
	var cam := Camera3D.new()
	main.level_root.add_child(cam)
	var p2: CharacterBody3D = main.player
	p2.model.rotation.y = 0
	cam.fov = 38
	cam.look_at_from_position(p2.global_position + Vector3(0.6, 1.5, -3.4), p2.global_position + Vector3(0, 1.45, 0), Vector3.UP)
	cam.current = true
	main.hud.visible = false
	await frames(8)
	_save(out, "hero_face")
	cam.look_at_from_position(p2.global_position + Vector3(2.5, 1.2, -4.2), p2.global_position + Vector3(0, 0.95, 0), Vector3.UP)
	await frames(4)
	_save(out, "hero_body")
	cam.look_at_from_position(p2.global_position + Vector3(0, 1.4, 4.0), p2.global_position + Vector3(0, 1.1, 0), Vector3.UP)
	await frames(4)
	_save(out, "hero_back")
	print("shots saved to ", out)


func _save(dir: String, name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(name + ".png"))
	print("saved ", name, " ", img.get_size())


# Measures which way the conveyor's chevrons move on screen (camera straight above, screen-up = -Z) and
# compares it with the direction the belt really pushes.
func _belt_motion(out: String) -> void:
	main.load_level(Levels.idx("city"))
	main._start_playing()
	main.hud.hide_screen()
	main.hud.visible = false
	main.player.respawn(Vector3(0, 0.05, -40))
	main.player.invuln = 0.0
	var belt: StaticBody3D = null
	for n in main.level_root.get_children():
		if n is StaticBody3D and n.constant_linear_velocity.length() > 0.1:
			belt = n
	var cam := Camera3D.new()
	main.level_root.add_child(cam)
	cam.fov = 40
	var bz := belt.global_position.z
	cam.look_at_from_position(Vector3(0, 12, bz), Vector3(0, 0, bz), Vector3(0, 0, -1))
	cam.current = true
	await frames(20)
	var a := get_viewport().get_texture().get_image()
	await frames(6)
	var b := get_viewport().get_texture().get_image()
	a.save_png(out.path_join("belt_a.png"))
	b.save_png(out.path_join("belt_b.png"))
	var cx := a.get_width() / 2
	var rows := a.get_height()
	var pa: Array[float] = []
	var pb: Array[float] = []
	for y in rows:
		var sa := 0.0
		var sb := 0.0
		for x in range(cx - 40, cx + 40, 4):
			sa += a.get_pixel(x, y).get_luminance()
			sb += b.get_pixel(x, y).get_luminance()
		pa.append(sa)
		pb.append(sb)
	var best := 0
	var best_err := INF
	for shift in range(-60, 61):
		var err := 0.0
		for y in range(130, rows - 130):
			err += absf(pa[y] - pb[y + shift])
		if err < best_err:
			best_err = err
			best = shift
	# feature at row y in frame A is at row y+best in frame B: negative = moved UP the screen = towards -Z
	var visual_z := -1.0 if best < 0 else 1.0
	var physical_z := signf(belt.constant_linear_velocity.z)
	print("belt: chevrons shift %d px (screen %s); belt pushes towards %s" % [best, "UP (-Z, away from the camera)" if best < 0 else "DOWN (+Z, towards the camera)", "-Z (away from the camera)" if physical_z < 0 else "+Z (towards the camera)"])
	_check(best != 0 and visual_z == physical_z, "conveyor: the chevrons move the way the belt pushes")
	# and at the belt's speed: speed * 6 frames at 60 fps, seen from 12 m up with a 40 degree lens
	var px_per_m := float(rows) / (2.0 * 12.0 * tan(deg_to_rad(20.0)))
	var expected_px: float = absf(belt.constant_linear_velocity.z) * (6.0 / 60.0) * px_per_m
	print("belt: moved %d px, expected about %.0f px for the belt's speed" % [absi(best), expected_px])
	_check(absf(absf(float(best)) - expected_px) < 10.0, "conveyor: the chevrons scroll at the belt's speed")
	cam.queue_free()
	main.hud.visible = true


# ------------------------------------------------------------------ boss

func _count_goals() -> int:
	var n := 0
	for c in main.level_root.get_children():
		if c.get_script() == preload("res://scripts/goal.gd"):
			n += 1
	return n


func _boss_tests() -> void:
	var Foam := preload("res://scripts/foam_ball.gd")
	main.load_level(Levels.idx("brewery"))
	main._start_playing()
	var p: CharacterBody3D = main.player
	var boss: Node3D = main.info.boss
	await frames(20)
	_check(boss.state == "intro" and boss.hp == 3, "boss wakes up when the fight starts (3 hits to go)")
	await frames(150)
	_check(boss.state != "intro" and boss.state != "wait", "boss finishes his intro and starts fighting")

	# --- he only takes damage while dizzy
	boss._set_state("wait")
	boss.position = Vector3(0, 0, -14)
	p.respawn(Vector3(0, 0.05, -10.7))
	p.invuln = 1000.0
	await frames(10)
	_tap("spin")
	await frames(3)
	_release_taps()
	await frames(10)
	_check(boss.hp == 3, "a fart does nothing to a boss who isn't dizzy")
	await frames(40)                 # let that fart finish before he becomes dizzy
	boss._set_state("dizzy")
	await frames(40)
	p.respawn(Vector3(0, 0.05, -10.7))
	await frames(10)
	_tap("spin")
	await frames(3)
	_release_taps()
	await frames(5)
	_check(boss.hp == 2 and boss.state == "hit", "a fart hurts a dizzy boss (reaching him from ~3 m)")
	await frames(90)
	_check(boss.state == "walk", "after a hit he recovers and carries on (state=%s t=%.2f hp=%d)" % [boss.state, boss.t, boss.hp])

	# --- stomping the foam crown while dizzy
	boss._set_state("dizzy")
	boss.position = Vector3(0, 0, -14)
	p.respawn(Vector3(0, boss.HEIGHT + 2.5, -14.0))
	p.invuln = 1000.0
	await frames(40)
	_check(boss.hp == 1, "stomping a dizzy boss's head hurts him")

	# --- foam balls
	boss._set_state("wait")
	Game.set_mask(true)
	p.respawn(Vector3(0, 0.05, 2.0))
	p.invuln = 0.0
	var ball := Foam.new()
	main.level_root.add_child(ball)
	ball.global_position = p.global_position + Vector3(0, 0.9, 0)
	await frames(4)
	_check(not Game.has_mask and p.invuln > 0.0, "a foam ball hurts the hero (here it just costs his shield)")
	p.invuln = 1000.0
	var ball2 := Foam.new()
	main.level_root.add_child(ball2)
	ball2.global_position = p.global_position + Vector3(0.0, 0.9, -1.2)
	await frames(2)
	_tap("spin")
	await frames(3)
	_release_taps()
	await frames(3)
	_check(not is_instance_valid(ball2) or ball2.done, "a fart pops a foam ball")

	# --- the slam's shockwave: hurts on the ground, harmless if you jump over it
	Game.set_mask(true)
	p.respawn(Vector3(3.2, 0.05, -14.0))
	p.invuln = 0.0
	boss.ring_origin = Vector3(0, 0, -14)
	boss.ring_r = 3.0
	await frames(3)
	_check(not Game.has_mask, "the shockwave ring hurts a hero standing on the ground")
	Game.set_mask(true)
	p.respawn(Vector3(3.2, 3.5, -14.0))
	p.invuln = 0.0
	boss.ring_r = 3.0
	await frames(40)
	_check(Game.has_mask, "...but he can jump over it")
	p.invuln = 1000.0

	# --- a charge ends in a crash and a dizzy boss
	boss.hp = 3
	boss.position = Vector3(0, 0, -14)
	p.respawn(Vector3(0, 0.05, 5.0))
	boss._set_state("charge")
	var dizzy_seen := false
	for i in 330:
		await frames(1)
		if boss.state == "dizzy":
			dizzy_seen = true
			break
	_check(dizzy_seen, "after a charge into the wall he is left dizzy")

	# --- the soak: left alone for 40 s he uses every attack, and nothing breaks
	main.load_level(Levels.idx("brewery"))
	main._start_playing()
	p = main.player
	boss = main.info.boss
	p.invuln = 100000.0
	var seen_states := {}
	for i in 2400:
		await frames(1)
		seen_states[boss.state] = true
	_check(seen_states.has("foam") and seen_states.has("slam") and seen_states.has("charge") and seen_states.has("dizzy"),
		"left alone he cycles through foam, slam, charge and dizzy (%s)" % str(seen_states.keys()))

	# --- dying: the hero respawns, the fight resumes with the boss's remaining health
	boss.hp = 2
	boss._set_state("foam")
	main._respawn()
	_check(boss.state == "walk" and boss.hp == 2, "after the hero dies the boss keeps his damage")

	# --- killing him
	boss.hp = 1
	boss.position = Vector3(0, 0, -14)
	boss._set_state("dizzy")
	p.respawn(Vector3(0, 0.05, -10.7))
	p.invuln = 1000.0
	await frames(10)
	_tap("spin")
	await frames(3)
	_release_taps()
	await frames(5)
	_check(boss.state == "dead", "the last hit finishes him")
	await frames(3 * 60 + 30)
	_check(not is_instance_valid(boss), "the dead boss blows up and disappears")
	_check(_count_goals() == 1, "the exit portal appears")
	_check(get_tree().get_nodes_in_group("fruit").size() >= 20, "a shower of beers falls")
	p.respawn(Vector3(0, 0.05, -13.6))
	await frames(40)
	_check(main.state == "complete" or main.state == "complete_wait", "walking into the portal completes the level")
	main.state = "playing"


func _boss_shots(out: String) -> void:
	main.load_level(Levels.idx("brewery"))
	main._start_playing()
	main.hud.banner.modulate.a = 0.0
	var p: CharacterBody3D = main.player
	var boss: Node3D = main.info.boss
	p.respawn(Vector3(0, 0.05, -2))
	p.invuln = 100000.0
	p.model.flash = 0.0
	main.cam_rig.snap()
	boss.position = Vector3(0, 0, -15)
	await frames(75)
	_save(out, "boss_intro")
	await frames(110)
	boss.position = Vector3(0, 0, -15)
	boss._set_state("foam")
	await frames(125)
	_save(out, "boss_foam")
	boss.position = Vector3(0, 0, -15)
	boss._set_state("slam")
	await frames(70)
	_save(out, "boss_slam_air")
	await frames(40)
	_save(out, "boss_ring")
	await frames(60)
	boss.position = Vector3(0, 0, -15)
	boss._set_state("charge")
	await frames(85)
	_save(out, "boss_charge")
	boss.position = Vector3(0, 0, -14)
	boss._set_state("dizzy")
	await frames(45)
	_save(out, "boss_dizzy")
	boss.position = Vector3(0, 0, -15)
	boss.hp = 1
	boss.take_hit(null)
	await frames(80)
	_save(out, "boss_death")
	await frames(130)
	_save(out, "boss_goal")


# ------------------------------------------------------------------ Don Humo (the cigar boss)

func _fart() -> void:
	_tap("spin")
	await frames(3)
	_release_taps()
	await frames(5)


func _cigar_tests() -> void:
	var Ember := preload("res://scripts/ember_strike.gd")
	main.load_level(Levels.idx("cigar"))
	main._start_playing()
	var p: CharacterBody3D = main.player
	var boss: Node3D = main.info.boss
	await frames(20)
	_check(boss.state == "intro" and boss.hp == 4, "Don Humo wakes up when the fight starts (4 hits to go)")
	await frames(150)
	_check(boss.state != "intro" and boss.state != "wait", "he finishes his intro and starts fighting")

	# --- only an overheated Don Humo can be hurt, and only by a fart next to his glowing tip
	boss._set_state("wait")
	boss.position = Vector3(0, 0, -14)
	p.respawn(Vector3(0, 0.05, -11.0))
	p.invuln = 1000.0
	await frames(10)
	await _fart()
	_check(boss.hp == 4, "a fart does nothing to a cigar who isn't overheated")
	await frames(40)
	boss._set_state("exposed")
	await frames(70)
	var tip: Vector3 = boss.tip_pos()
	_check(tip.distance_to(boss.position) > 3.0 and Vector2(tip.x, tip.z).length() < 12.0, "overheated: he is on his back with the tip inside the arena")
	p.respawn(Vector3(0, 0.05, 6.0))
	await frames(10)
	await _fart()
	_check(boss.hp == 4, "a fart far away from his tip does nothing")
	await frames(40)
	p.respawn(Vector3(tip.x, 0.05, tip.z + 1.2))
	await frames(10)
	await _fart()
	_check(boss.hp == 3 and boss.state == "hit", "a fart next to the glowing tip ignites it and hurts him")
	await frames(110)
	_check(boss.state == "walk", "after the explosion he gets back up and carries on")

	# --- ember rain: a burning patch hurts on the ground, not in the air
	boss._set_state("wait")
	Game.set_mask(true)
	p.respawn(Vector3(-5.0, 0.05, 2.0))
	p.invuln = 0.0
	var e := Ember.new()
	main.level_root.add_child(e)
	e.global_position = Vector3(-5.0, 0.0, 2.0)
	for i in 120:
		await frames(1)
		if e.state == "burn" or not is_instance_valid(e):
			break
	await frames(3)
	_check(not Game.has_mask, "an ember landing on the hero hurts him")
	var e2 := Ember.new()
	main.level_root.add_child(e2)
	e2.global_position = Vector3(5.0, 0.0, 2.0)
	for i in 120:
		await frames(1)
		if e2.state == "burn":
			break
	Game.set_mask(true)
	p.respawn(Vector3(5.0, 3.2, 2.0))
	p.invuln = 0.0
	await frames(12)
	_check(Game.has_mask, "he can jump over a burning patch")
	p.invuln = 1000.0
	await frames(60)
	p.respawn(Vector3(5.0, 0.05, 2.0))
	p.invuln = 0.0
	await frames(4)
	_check(not Game.has_mask, "...but standing in it burns")
	p.invuln = 1000.0

	# --- the flame sweep: a wall of fire along the floor
	boss.position = Vector3(0, 0, -14)
	boss._set_state("sweep")
	boss.step = 1
	boss.t = 0.0
	boss.beam.visible = true
	boss.yaw = 0.0
	Game.set_mask(true)
	p.respawn(Vector3(0.0, 0.05, -19.0))
	p.invuln = 0.0
	await frames(3)
	_check(not Game.has_mask, "the flame wall hurts a hero standing in it")
	Game.set_mask(true)
	boss.yaw = 0.0
	p.respawn(Vector3(0.0, 3.2, -19.0))
	p.invuln = 0.0
	await frames(6)
	_check(Game.has_mask, "he can jump over the flame wall")
	p.invuln = 1000.0

	# --- the rolling smash
	boss.position = Vector3(0, 0, -14)
	boss._set_state("roll")
	boss.step = 1
	boss.t = 0.0
	boss.dash_dir = Vector3(0, 0, 1)
	boss.fall_dir = boss.dash_dir.rotated(Vector3.UP, PI / 2.0)
	boss.lay = 1.0
	boss.lay_target = 1.0
	Game.set_mask(true)
	p.respawn(Vector3(0.0, 0.05, -12.0))
	p.invuln = 0.0
	await frames(3)
	_check(not Game.has_mask, "being run over by the rolling cigar hurts")
	boss.position = Vector3(0, 0, -14)
	p.respawn(Vector3(0.0, 0.05, 5.0))
	p.invuln = 1000.0          # (respawn() resets the protection to 1.6 s)
	boss._set_state("roll")
	var smashed := false
	for i in 420:
		await frames(1)
		if boss.step == 2:
			smashed = true
			break
	_check(smashed, "the roll ends in a smash into the wall")

	# --- after the sweep he is overheated (that's the opening)
	boss.position = Vector3(0, 0, -14)
	boss._set_state("sweep")
	var overheated := false
	for i in 600:
		await frames(1)
		if boss.state == "exposed":
			overheated = true
			break
	_check(overheated, "after the flame sweep he overheats and is exposed")

	# --- the soak: left alone he uses every attack, in order, and nothing breaks
	main.load_level(Levels.idx("cigar"))
	main._start_playing()
	p = main.player
	boss = main.info.boss
	p.invuln = 100000.0
	var seen_states := {}
	for i in 3600:
		await frames(1)
		seen_states[boss.state] = true
	_check(seen_states.has("rain") and seen_states.has("sweep") and seen_states.has("exposed") and seen_states.has("roll"),
		"left alone he cycles through rain, sweep, overheat and roll (%s)" % str(seen_states.keys()))

	boss.hp = 3
	boss._set_state("rain")
	main._respawn()
	_check(boss.state == "walk" and boss.hp == 3, "after the hero dies the cigar keeps his damage")

	# --- burning him out
	boss.hp = 1
	boss.position = Vector3(0, 0, -14)
	boss._set_state("exposed")
	await frames(70)
	tip = boss.tip_pos()
	p.respawn(Vector3(tip.x, 0.05, tip.z + 1.2))
	p.invuln = 1000.0
	await frames(10)
	await _fart()
	_check(boss.state == "dead", "the last explosion burns him out")
	await frames(3 * 60 + 30)
	_check(not is_instance_valid(boss), "the cigar goes up and disappears")
	_check(_count_goals() == 1, "the exit portal appears")
	_check(get_tree().get_nodes_in_group("fruit").size() >= 20, "a shower of beers falls")
	p.respawn(Vector3(0, 0.05, -13.6))
	await frames(40)
	_check(main.state == "complete" or main.state == "complete_wait", "walking into the portal completes the level")
	main.state = "playing"


func _cigar_shots(out: String) -> void:
	main.load_level(Levels.idx("cigar"))
	main._start_playing()
	main.hud.banner.modulate.a = 0.0
	var p: CharacterBody3D = main.player
	var boss: Node3D = main.info.boss
	p.respawn(Vector3(0, 0.05, -2))
	p.invuln = 100000.0
	p.model.flash = 0.0
	main.cam_rig.snap()
	boss.position = Vector3(0, 0, -15)
	await frames(80)
	_save(out, "cigar_intro")
	await frames(110)
	boss.position = Vector3(0, 0, -15)
	boss._set_state("rain")
	await frames(95)
	_save(out, "cigar_rain_warn")
	await frames(60)
	_save(out, "cigar_rain_fire")
	for h in get_tree().get_nodes_in_group("hazard"):
		h.queue_free()
	await frames(10)
	boss.position = Vector3(0, 0, -15)
	boss._set_state("sweep")
	await frames(115)
	_save(out, "cigar_sweep")
	for i in 600:
		await frames(1)
		if boss.state == "exposed":
			break
	await frames(70)
	_save(out, "cigar_exposed")
	var tip: Vector3 = boss.tip_pos()
	p.respawn(Vector3(tip.x, 0.05, tip.z + 1.6))
	p.model.flash = 0.0
	await frames(8)
	_tap("spin")
	await frames(10)
	_release_taps()
	_save(out, "cigar_ignite")
	await frames(120)
	boss.position = Vector3(0, 0, -15)
	p.respawn(Vector3(0, 0.05, -2))
	p.model.flash = 0.0
	boss._set_state("roll")
	await frames(100)
	_save(out, "cigar_roll")
	await frames(120)
	boss.hp = 1
	boss.position = Vector3(0, 0, -15)
	boss._set_state("exposed")
	await frames(70)
	tip = boss.tip_pos()
	p.respawn(Vector3(tip.x, 0.05, tip.z + 1.6))
	await frames(8)
	_tap("spin")
	await frames(60)
	_release_taps()
	_save(out, "cigar_death")
	await frames(140)
	_save(out, "cigar_goal")


# ------------------------------------------------------------------ credits

func _credits_tests() -> void:
	main.load_level(Levels.idx("brewery"))
	main._start_playing()
	await frames(10)
	main._start_credits()
	await frames(5)
	_check(main.state == "credits" and main.has_node("Credits"), "the credits start after the last boss")
	var c: CanvasLayer = main.get_node("Credits")
	var lines: Array = c.credit_lines
	_check("Starring: Palmouze" in lines and "Made by: Love for Palmouze" in lines and "Inspired by: Palmouze" in lines,
		"the credits say Starring / Made by: Love for / Inspired by Palmouze (%s)" % str(lines))
	_check(Sfx.sounds.has("birthday") and Sfx.sounds["birthday"].get_length() > 10.0, "the birthday tune plays (%.1f s long)" % Sfx.sounds["birthday"].get_length())
	c.t = 5.0
	await frames(3)
	_check(c.title_box.modulate.a > 0.95 and c.section_box.get_parent().modulate.a < 0.05, "at the start the big HAPPY BIRTHDAY title is showing")
	_check(not main.hud.visible, "the HUD is hidden during the credits")
	var expected := [["Starring", "Palmouze"], ["Made by", "Love for Palmouze"], ["Inspired by", "Palmouze"]]
	for i in 3:
		c.t = 12.8 + i * 3.8 + 1.5
		await frames(3)
		_check(c.role_label.text == expected[i][0] and c.name_label.text == expected[i][1] and c.section_box.get_parent().modulate.a > 0.95 and c.title_box.modulate.a < 0.05,
			"credit %d shows \"%s: %s\"" % [i + 1, expected[i][0], expected[i][1]])
	c.t = 28.0
	await frames(3)
	_check(c.finale_box.modulate.a > 0.95, "the credits end with a last birthday wish")
	# Enter skips
	c.t = 5.0
	_tap("confirm")
	await frames(3)
	_release_taps()
	await frames(3)
	_check(main.state == "complete_wait" and not main.has_node("Credits") and main.hud.visible, "Enter skips the credits and leads to THE END screen")
	# left alone it ends by itself
	main.state = "playing"
	main._start_credits()
	for i in 2100:
		await frames(1)
		if main.state == "complete_wait":
			break
	_check(main.state == "complete_wait" and not main.has_node("Credits"), "left alone, the credits end by themselves")
	main.state = "playing"


func _credits_shots(out: String) -> void:
	main.load_level(Levels.idx("brewery"))
	main._start_playing()
	main.hud.banner.modulate.a = 0.0
	main.player.respawn(Vector3(0, 0.05, -4))
	main.player.model.flash = 0.0
	main.player.celebrate()
	await frames(30)
	main._start_credits()
	var c: CanvasLayer = main.get_node("Credits")
	for step in [[4.0, "credits_title"], [14.0, "credits_starring"], [18.0, "credits_made"], [22.0, "credits_inspired"], [27.0, "credits_finale"]]:
		c.t = step[0]
		await frames(25)
		_save(out, step[1])
	c.finish()
	await frames(10)
	_save(out, "the_end")
	main.state = "playing"
