extends Node
# Global game state (autoload "Game"): counters, checkpoint, input map, shared references.

signal changed
signal message(text: String, seconds: float)
signal level_completed
signal screen_flash(color: Color)
signal puke

const START_LIVES := 5
const FRUIT_FOR_LIFE := 100

var fruit := 0
var lives := START_LIVES
var crates_broken := 0
var crates_total := 0
var gems := 0
var gems_total := 0
var has_mask := false
var checkpoint = null          # Vector3 or null
var kill_y := -12.0
var player: Node3D = null
var camera_rig: Node3D = null
var face_texture: Texture2D = null
var hero: Dictionary = {}
var level_active := false


func _ready() -> void:
	_setup_input()


func reset_run() -> void:
	fruit = 0
	lives = START_LIVES
	has_mask = false


func reset_level() -> void:
	crates_broken = 0
	crates_total = 0
	gems = 0
	gems_total = 0
	checkpoint = null
	has_mask = false
	changed.emit()


func add_fruit(n: int) -> void:
	fruit += n
	if fruit >= FRUIT_FOR_LIFE:
		fruit -= FRUIT_FOR_LIFE
		add_life()
		message.emit("BLEURGH!  EXTRA LIFE!", 2.2)
		puke.emit()
	changed.emit()


func add_gem() -> void:
	gems += 1
	Sfx.play("gem")
	message.emit("GEM!  +10 beers", 1.5)
	add_fruit(10)


func add_life() -> void:
	lives += 1
	Sfx.play("life")
	message.emit("EXTRA LIFE!", 1.6)
	changed.emit()


func crate_broken() -> void:
	crates_broken += 1
	changed.emit()


func set_mask(on: bool) -> void:
	has_mask = on
	changed.emit()


func set_checkpoint(pos: Vector3) -> void:
	checkpoint = pos
	message.emit("CHECKPOINT!", 1.4)


func shake(amount: float) -> void:
	if camera_rig and camera_rig.has_method("shake"):
		camera_rig.shake(amount)


# Hit everything breakable / killable near a point. Returns number of targets affected.
func hit_area(center: Vector3, radius: float, how: String, source: Node3D) -> int:
	var n := 0
	for group in ["crate", "enemy"]:
		for node in get_tree().get_nodes_in_group(group):
			if not is_instance_valid(node):
				continue
			var d: Vector3 = node.global_position - center
			var planar := Vector2(d.x, d.z).length()
			if planar <= radius and absf(d.y) <= 1.9:
				node.hit(source, how)
				n += 1
	return n


# ------------------------------------------------------------------ input

func _key(action: String, keys: Array, buttons: Array = [], axes: Array = []) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = b
		InputMap.action_add_event(action, jb)
	for a in axes:
		var jm := InputEventJoypadMotion.new()
		jm.axis = a[0]
		jm.axis_value = a[1]
		InputMap.action_add_event(action, jm)


func _setup_input() -> void:
	_key("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_key("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_key("move_forward", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], [[JOY_AXIS_LEFT_Y, -1.0]])
	_key("move_back", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], [[JOY_AXIS_LEFT_Y, 1.0]])
	_key("jump", [KEY_SPACE, KEY_K], [JOY_BUTTON_A])
	_key("spin", [KEY_J, KEY_X, KEY_SHIFT], [JOY_BUTTON_X, JOY_BUTTON_Y])
	_key("slide", [KEY_C, KEY_CTRL, KEY_L], [JOY_BUTTON_B, JOY_BUTTON_RIGHT_SHOULDER])
	_key("confirm", [KEY_ENTER, KEY_KP_ENTER], [JOY_BUTTON_START, JOY_BUTTON_A])
	_key("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])
	_key("restart", [KEY_R], [JOY_BUTTON_BACK])
	# mouse: left click = spin
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("spin", mb)
