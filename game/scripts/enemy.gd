extends Node3D
# Patrolling enemies. "crab": stomp or spin it. "spiky": only spin/slide/slam (stomping hurts).

const T = preload("res://scripts/toon.gd")

var kind := "crab"
var axis := Vector3.RIGHT
var dist := 3.0
var speed := 1.6
var origin := Vector3.ZERO
var t := 0.0
var dead := false
var claws: Array[Node3D] = []
var body: Node3D
var last_pos := Vector3.ZERO


func setup(k: String, ax: Vector3, d: float, spd: float) -> void:
	kind = k
	axis = ax
	dist = d
	speed = spd


func _ready() -> void:
	add_to_group("enemy")
	origin = position
	last_pos = position
	t = randf() * TAU
	body = Node3D.new()
	add_child(body)
	if kind == "spiky":
		_build_spiky()
	else:
		_build_crab()


func _build_crab() -> void:
	var red := T.mat(Color(0.92, 0.25, 0.2))
	var dark := T.mat(Color(0.65, 0.12, 0.12))
	T.sphere(body, 0.5, Vector3(0, 0.42, 0), red, Vector3(1.25, 0.72, 1.0))
	for sx in [-1.0, 1.0]:
		var claw := Node3D.new()
		claw.position = Vector3(sx * 0.72, 0.5, -0.32)
		body.add_child(claw)
		T.sphere(claw, 0.26, Vector3.ZERO, dark, Vector3(1.0, 0.9, 1.2))
		T.sphere(claw, 0.14, Vector3(sx * 0.12, 0.1, -0.22), red)
		claws.append(claw)
		# eye stalk
		T.cylinder(body, 0.045, 0.045, 0.3, Vector3(sx * 0.2, 0.9, -0.28), dark, 8)
		var eye := T.sphere(body, 0.14, Vector3(sx * 0.2, 1.1, -0.3), T.mat(Color.WHITE, true, 0.3, null, 0.02))
		T.sphere(eye, 0.075, Vector3(0, 0, -0.08), T.mat(Color(0.05, 0.05, 0.1), false))
		# legs
		for i in 3:
			var leg := T.capsule(body, 0.04, 0.4, Vector3(sx * 0.55, 0.12, -0.25 + i * 0.25), dark)
			leg.rotation.z = sx * 0.9


func _build_spiky() -> void:
	var purple := T.mat(Color(0.55, 0.25, 0.75))
	var spike := T.mat(Color(0.95, 0.85, 0.35))
	T.sphere(body, 0.55, Vector3(0, 0.6, 0), purple)
	for i in 22:
		var y := 1.0 - 2.0 * (i + 0.5) / 22.0
		var r := sqrt(1.0 - y * y)
		var a := i * 2.399963
		var dir := Vector3(cos(a) * r, y, sin(a) * r)
		var s := T.cylinder(body, 0.0, 0.1, 0.38, Vector3(0, 0.6, 0) + dir * 0.66, spike, 8)
		s.look_at_from_position(s.position, s.position + dir, Vector3.UP)
		s.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	for sx in [-1.0, 1.0]:
		var eye := T.sphere(body, 0.14, Vector3(sx * 0.2, 0.72, -0.5), T.mat(Color.WHITE, true, 0.3, null, 0.02))
		T.sphere(eye, 0.07, Vector3(0, 0, -0.1), T.mat(Color(0.05, 0.05, 0.1), false))
		var brow := T.box(body, Vector3(0.24, 0.06, 0.06), Vector3(sx * 0.2, 0.9, -0.5), T.mat(Color(0.1, 0.05, 0.15), false))
		brow.rotation.z = sx * 0.5


func _physics_process(delta: float) -> void:
	if dead:
		return
	t += delta
	if speed > 0.01 and dist > 0.01:
		position = origin + axis * sin(t * speed / dist * 1.0) * dist
	var mv := position - last_pos
	last_pos = position
	if mv.length() > 0.0005:
		body.rotation.y = lerp_angle(body.rotation.y, atan2(-mv.x, -mv.z) if kind == "spiky" else 0.0, 0.1)
	if kind == "crab":
		for i in claws.size():
			claws[i].rotation.x = sin(t * 7.0 + i * PI) * 0.4
		body.position.y = absf(sin(t * 6.0)) * 0.06
	else:
		body.rotation.x = sin(t * 3.0) * 0.08

	var pl: Node3D = Game.player
	if pl == null or not is_instance_valid(pl) or pl.dead or pl.celebrating:
		return
	var d: Vector3 = pl.global_position - global_position
	if Vector2(d.x, d.z).length() < 0.95 and d.y > -1.5 and d.y < 1.2:
		if kind != "spiky" and pl.velocity.y < -0.5 and d.y > 0.45:
			_die(true)
			pl.bounce(10.0)
		elif pl.is_spinning() or pl.is_sliding():
			hit(pl, "spin")
		else:
			pl.hurt()


func hit(player: Node3D, how: String) -> void:
	if dead:
		return
	if how == "stomp":
		if kind == "spiky":
			return
	_die(false)


func _die(squash: bool) -> void:
	if dead:
		return
	dead = true
	remove_from_group("enemy")
	Sfx.play("enemy")
	Game.add_fruit(2)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.4, 0.08, 1.4), 0.1)
	tw.tween_property(self, "scale", Vector3.ZERO, 0.15)
	tw.tween_callback(queue_free)
	var p := CPUParticles3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	p.mesh = mesh
	p.material_override = T.emissive(Color(1, 0.9, 0.5), 1.2)
	p.amount = 14
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.6
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -10, 0)
	p.emitting = true
	get_parent().add_child(p)
	p.global_position = global_position + Vector3(0, 0.5, 0)
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)
