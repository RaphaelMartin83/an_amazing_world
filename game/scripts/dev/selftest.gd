extends Node
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
	main._select_level(2)
	_check(main.level_index == 2 and main.state == "title", "title screen: picking 3 loads the sewer")
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
	main.load_level(3)
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
	main.load_level(5)
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
	main.load_level(4)
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
	main.load_level(4)
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

	print("== bot plays level 1 (Jungle Run)")
	await _play(0, 150.0)
	print("== bot plays level 2 (Boulder Rush)")
	await _play(1, 150.0)
	print("== bot plays level 3 (Sewer Surge)")
	await _play(2, 150.0)
	print("== bot plays level 4 (Neon Rooftops)")
	await _play(3, 200.0)
	print("== bot plays level 5 (Sunny Shores)")
	await _play(4, 200.0)
	print("== bot plays level 6 (Frozen Peaks)")
	await _play(5, 200.0)
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
	_check(done, "level %d is completable by the bot" % (idx + 1))
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
		[2, "L3_start", Vector3(0, 0.05, -1), 2],
		[2, "L3_crumble", Vector3(0, 0.05, -58), 2],
		[2, "L3_toys", Vector3(0, 0.05, -95), 2],
		[2, "L3_movers", Vector3(0, 0.05, -118), 2],
		[2, "L3_pump", Vector3(0, 0.05, -152), 2],
		[3, "L4_start", Vector3(0, 0.05, -1), 3],
		[3, "L4_conveyor", Vector3(0, 0.05, -47), 3],
		[3, "L4_stairs", Vector3(0, 0.05, -90), 3],
		[3, "L4_movers", Vector3(0, 2.65, -118), 3],
		[3, "L4_garden", Vector3(0, 2.65, -156), 3],
		[3, "L4_scaffold", Vector3(0, 2.65, -186), 3],
		[4, "L5_start", Vector3(0, 0.05, -1), 4],
		[4, "L5_boardwalk", Vector3(0, 0.05, -46), 4],
		[4, "L5_rafts", Vector3(0, 0.05, -90), 4],
		[4, "L5_wave", Vector3(0, 0.05, -122), 4],
		[4, "L5_pier", Vector3(0, 0.05, -154), 4],
		[5, "L6_start", Vector3(0, 0.05, -1), 5],
		[5, "L6_ice", Vector3(0, 0.05, -16), 5],
		[5, "L6_floes", Vector3(0, 0.05, -42), 5],
		[5, "L6_rink", Vector3(0, 0.05, -96), 5],
		[5, "L6_climb", Vector3(0, 1.35, -142), 5],
		[5, "L6_summit", Vector3(0, 3.95, -180), 5],
	]
	main._select_level(1)
	await frames(30)
	_save(out, "title")
	await _belt_motion(out)
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
	main.load_level(3)
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
