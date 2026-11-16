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
	_check(Game.fruit == fruit_before + 1, "breaking a crate gives a mango")

	# jump on a crate
	p.respawn(Vector3(2.5, 3.0, -9.0))
	await frames(40)
	_check(Game.crates_broken == before + 2, "landing on a crate breaks it")

	print("== bot plays level 1 (Jungle Run)")
	await _play(0, 150.0)
	print("== bot plays level 2 (Boulder Rush)")
	await _play(1, 150.0)
	print("== result: %s (%d failures)" % ["OK" if failures == 0 else "FAILED", failures])


func _play(idx: int, timeout_s: float) -> void:
	Game.reset_run()
	main.load_level(idx)
	main._start_playing()
	var dir := Vector3(0, 0, -1) if idx == 0 else Vector3(0, 0, 1)
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
	print("  finished=%s  time=%.1fs  deaths=%d %s  mangoes=%d  crates=%d/%d" % [str(done), t, deaths, str(death_log), Game.fruit, Game.crates_broken, Game.crates_total])
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
		[0, "L1_goal", Vector3(0, 3.05, -203), 0],
		[1, "L2_start", Vector3(0, 0.05, -92), 1],
		[1, "L2_mid", Vector3(0, 0.05, -30), 1],
		[1, "L2_causeway", Vector3(0, 0.05, 28), 1],
	]
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
		await frames(50)
		main.cam_rig.snap()
		await frames(4)
		_save(out, s[1])
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
