extends AnimatableBody3D
# A rusty grate that shakes and drops shortly after the hero lands on it, then comes back a few seconds later.

const T = preload("res://scripts/toon.gd")
const SHAKE_TIME := 0.55
const RESPAWN_TIME := 3.2

var size := Vector3(3.6, 0.5, 3.6)
var style := "metal"   # metal | wood | ice
var origin := Vector3.ZERO
var state := "idle"
var timer := 0.0
var fall_v := 0.0
var shape: CollisionShape3D
var visual: Node3D


func _ready() -> void:
	add_to_group("crumble")
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = true
	origin = position
	shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)
	visual = Node3D.new()
	add_child(visual)
	var top := size.y * 0.5 + 0.015
	match style:
		"wood":
			var wood := T.mat(Color(0.55, 0.36, 0.2), true, 0.8, T.plank_tex("planks", Color(0.50, 0.32, 0.18), Color(0.72, 0.5, 0.3)), 0.03)
			T.box(visual, size, Vector3.ZERO, wood)
			var nail := T.mat(Color(0.25, 0.25, 0.28), false)
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					T.sphere(visual, 0.08, Vector3(sx * (size.x * 0.5 - 0.3), top, sz * (size.z * 0.5 - 0.3)), nail)
			T.box(visual, Vector3(size.x - 0.2, 0.05, 0.12), Vector3(0, top, 0), T.mat(Color(0.3, 0.18, 0.1), false))
		"ice":
			add_to_group("ice")
			var ice := T.mat(Color(0.62, 0.86, 1.0), true, 0.15, null, 0.03)
			T.box(visual, size, Vector3.ZERO, ice)
			var crack := T.mat(Color(0.25, 0.5, 0.75), false)
			T.box(visual, Vector3(size.x * 0.7, 0.04, 0.07), Vector3(0.2, top, -0.4), crack).rotation.y = 0.4
			T.box(visual, Vector3(size.x * 0.5, 0.04, 0.07), Vector3(-0.3, top, 0.6), crack).rotation.y = -0.7
		_:
			var metal := T.mat(Color(0.36, 0.34, 0.33), true, 0.5, null, 0.03)
			var dark := T.mat(Color(0.14, 0.13, 0.13), false, 0.6)
			var amber := T.emissive(Color(1.0, 0.55, 0.1), 0.9)
			T.box(visual, size, Vector3.ZERO, metal)
			for i in 5:
				T.box(visual, Vector3(size.x - 0.5, 0.04, 0.16), Vector3(0, top, -size.z * 0.5 + 0.45 + i * (size.z - 0.9) / 4.0), dark)
			for sx in [-1.0, 1.0]:
				T.box(visual, Vector3(0.12, 0.05, size.z - 0.1), Vector3(sx * (size.x * 0.5 - 0.1), top, 0), amber)
			for sz in [-1.0, 1.0]:
				T.box(visual, Vector3(size.x - 0.1, 0.05, 0.12), Vector3(0, top, sz * (size.z * 0.5 - 0.1)), amber)


func _physics_process(delta: float) -> void:
	match state:
		"idle":
			var pl: Node3D = Game.player
			if pl and is_instance_valid(pl) and not pl.dead and pl.is_on_floor():
				var d := pl.global_position - global_position
				if absf(d.x) < size.x * 0.5 + 0.1 and absf(d.z) < size.z * 0.5 + 0.1 \
						and d.y > size.y * 0.5 - 0.15 and d.y < size.y * 0.5 + 0.4:
					state = "shaking"
					timer = SHAKE_TIME
					Sfx.play("clank")
		"shaking":
			timer -= delta
			visual.position = Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)) * 0.06
			if timer <= 0.0:
				state = "falling"
				fall_v = 0.0
				visual.position = Vector3.ZERO
				shape.set_deferred("disabled", true)
		"falling":
			fall_v += 30.0 * delta
			position.y -= fall_v * delta
			if position.y < origin.y - 9.0:
				state = "gone"
				timer = RESPAWN_TIME
				visible = false
		"gone":
			timer -= delta
			if timer <= 0.0:
				position = origin
				reset_physics_interpolation()
				visible = true
				shape.set_deferred("disabled", false)
				state = "idle"
