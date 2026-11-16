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
	shape.size = Vector3(length, 0.6, 0.6)
	cs.shape = shape
	cs.position = Vector3(0, height, 0)
	add_child(cs)
	_arms()
	T.cylinder(self, 0.3, 0.45, height * 2.0, Vector3(0, height * 0.5, 0), T.mat(Color(0.4, 0.4, 0.45)))


# Two cartoon novelty toys sticking out of the hub: a rounded shaft with a flared base, one pink and one purple.
func _arms() -> void:
	var half := length * 0.5
	var shaft_len := half - 0.55
	var tones := [Color(1.0, 0.42, 0.68), Color(0.62, 0.42, 0.95)]
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var m := T.mat(tones[i], true, 0.3)
		var shaft := T.capsule(self, 0.3, shaft_len, Vector3(side * (0.55 + shaft_len * 0.5), height, 0), m)
		shaft.rotation.z = PI / 2.0
		var base := T.cylinder(self, 0.5, 0.5, 0.28, Vector3(side * 0.45, height, 0), m)
		base.rotation.z = PI / 2.0
		# little shine so the toon material reads as glossy plastic
		T.sphere(self, 0.07, Vector3(side * (0.55 + shaft_len * 0.75), height + 0.2, -0.12), T.emissive(Color(1, 1, 1), 1.2))


func _physics_process(delta: float) -> void:
	rotation.y += speed * delta
	var pl: Node3D = Game.player
	if pl == null or not is_instance_valid(pl) or pl.dead:
		return
	var local := to_local(pl.global_position)
	var py := pl.global_position.y - global_position.y
	if absf(local.x) < length * 0.5 + 0.4 and absf(local.z) < 0.65 and py > height - 1.7 and py < height + 0.55:
		pl.hurt()
