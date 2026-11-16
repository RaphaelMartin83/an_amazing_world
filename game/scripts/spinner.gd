extends AnimatableBody3D
# A spinning bar hazard. Solid (shoves the hero) and hurts on contact.

const T = preload("res://scripts/toon.gd")

var length := 7.0
var speed := 1.6
var height := 0.9


func _ready() -> void:
	add_to_group("spinner")
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = true
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(length, 0.5, 0.5)
	cs.shape = shape
	cs.position = Vector3(0, height, 0)
	add_child(cs)
	T.box(self, Vector3(length, 0.5, 0.5), Vector3(0, height, 0), T.mat(Color(0.55, 0.32, 0.18)))
	for sx in [-1.0, 1.0]:
		T.sphere(self, 0.42, Vector3(sx * length * 0.5, height, 0), T.mat(Color(0.9, 0.2, 0.25)))
	T.cylinder(self, 0.3, 0.45, height * 2.0, Vector3(0, height * 0.5, 0), T.mat(Color(0.4, 0.4, 0.45)))


func _physics_process(delta: float) -> void:
	rotation.y += speed * delta
	var pl: Node3D = Game.player
	if pl == null or not is_instance_valid(pl) or pl.dead:
		return
	var local := to_local(pl.global_position)
	var py := pl.global_position.y - global_position.y
	if absf(local.x) < length * 0.5 + 0.4 and absf(local.z) < 0.65 and py > height - 1.7 and py < height + 0.55:
		pl.hurt()
