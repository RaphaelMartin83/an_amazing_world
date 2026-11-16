extends AnimatableBody3D
# Platform that slides back and forth along an axis.

var axis := Vector3.RIGHT
var dist := 3.0
var speed := 1.2
var phase := 0.0
var origin := Vector3.ZERO
var t := 0.0


func _ready() -> void:
	add_to_group("mover")
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = true
	origin = position


func _physics_process(delta: float) -> void:
	t += delta
	position = origin + axis * sin(t * speed + phase) * dist
