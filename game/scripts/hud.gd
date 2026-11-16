extends CanvasLayer
# On-screen UI, built entirely in code: counters, banners, title / complete / game-over screens, pause, fade.

const FaceIcon = preload("res://scripts/face_icon.gd")

var lives_label: Label
var fruit_label: Label
var crate_label: Label
var shield_label: Label
var message_label: Label
var banner: Label
var title_box: VBoxContainer
var title_name: Label
var title_sub: Label
var title_hint: Label
var info_label: Label
var fade: ColorRect
var pause_box: Label
var msg_t := 0.0
var banner_t := 0.0
var _fade_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# --- top-left: face + lives
	var face := TextureRect.new()
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture = Game.face_texture
	root.add_child(face)
	face.position = Vector2(14, 8)
	face.size = Vector2(84, 84)
	lives_label = _label(root, 44, Vector2(104, 22))
	shield_label = _label(root, 22, Vector2(104, 74))
	shield_label.add_theme_color_override("font_color", Color(0.7, 0.95, 1.0))

	# --- top-right: fruit + crates
	fruit_label = _label(root, 44, Vector2.ZERO)
	_place(fruit_label, Control.PRESET_TOP_WIDE, 18, 66, 24)
	fruit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	crate_label = _label(root, 26, Vector2.ZERO)
	_place(crate_label, Control.PRESET_TOP_WIDE, 74, 108, 24)
	crate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# --- centre message (pickups, checkpoint ...)
	message_label = _label(root, 54, Vector2.ZERO)
	_place(message_label, Control.PRESET_TOP_WIDE, 150, 220, 0)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	message_label.modulate.a = 0.0

	banner = _label(root, 72, Vector2.ZERO)
	banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	banner.modulate.a = 0.0

	# --- title / end screens
	title_box = VBoxContainer.new()
	title_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.add_theme_constant_override("separation", 14)
	root.add_child(title_box)
	title_name = _label(title_box, 96, Vector2.ZERO)
	title_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_name.add_theme_color_override("font_color", Color(1.0, 0.82, 0.2))
	title_name.add_theme_constant_override("outline_size", 22)
	title_sub = _label(title_box, 44, Vector2.ZERO)
	title_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label = _label(title_box, 24, Vector2.ZERO)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_hint = _label(title_box, 40, Vector2.ZERO)
	title_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_hint.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))

	pause_box = _label(root, 64, Vector2.ZERO)
	pause_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_box.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_box.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pause_box.text = "PAUSED\n[Esc] resume   [Q] quit"
	pause_box.visible = false

	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)

	Game.changed.connect(refresh)
	refresh()


# Full-width strip with the given top/bottom offsets and a right margin.
func _place(c: Control, preset: int, top: float, bottom: float, margin_right: float) -> void:
	c.set_anchors_and_offsets_preset(preset)
	c.offset_top = top
	c.offset_bottom = bottom
	c.offset_right = -margin_right


func _label(parent: Node, size: int, pos: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.12))
	l.add_theme_constant_override("outline_size", maxi(6, size / 5))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func refresh() -> void:
	lives_label.text = "x %d" % Game.lives
	fruit_label.text = "%d  (mango)" % Game.fruit
	crate_label.text = "crates %d / %d" % [Game.crates_broken, Game.crates_total]
	shield_label.text = "SHIELD" if Game.has_mask else ""


func _process(delta: float) -> void:
	if msg_t > 0.0:
		msg_t -= delta
		message_label.modulate.a = clampf(msg_t * 3.0, 0.0, 1.0)
	if banner_t > 0.0:
		banner_t -= delta
		banner.modulate.a = clampf(banner_t * 2.0, 0.0, 1.0)


func show_message(text: String, seconds := 1.5) -> void:
	message_label.text = text
	msg_t = seconds
	message_label.modulate.a = 1.0


func show_banner(text: String, seconds := 2.6) -> void:
	banner.text = text
	banner_t = seconds
	banner.modulate.a = 1.0


func show_screen(title: String, sub: String, info: String, hint: String) -> void:
	title_name.text = title
	title_sub.text = sub
	info_label.text = info
	title_hint.text = hint
	title_box.visible = true


func hide_screen() -> void:
	title_box.visible = false


func fade_to(alpha: float, seconds: float) -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(fade, "color:a", alpha, seconds)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and title_box.visible == false:
		get_tree().paused = not get_tree().paused
		pause_box.visible = get_tree().paused
		Sfx.set_music(not get_tree().paused)
	elif get_tree().paused and event is InputEventKey and event.pressed and event.physical_keycode == KEY_Q:
		get_tree().quit()
