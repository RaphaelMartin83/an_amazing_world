extends CanvasLayer
# The ending: a big animated "HAPPY BIRTHDAY <NAME>" with confetti, fireworks and a birthday tune, then the
# credits (Starring / Made by / Inspired by), then a last birthday wish. Enter skips.
# Everything is a pure function of the timeline `t`, so it can be jumped around (the tests do).

signal finished

const Confetti = preload("res://scripts/confetti.gd")

const TITLE_END := 11.8
const SECTION_START := 12.8
const SECTION_LEN := 3.8
const FINALE_START := 24.4
const END_TIME := 32.0

var t := 0.0
var hero_name := ""
var credit_lines: Array[String] = []     # "Role: Name" (kept so the tests can read what is shown)
var _done := false
var _next_burst := 0.5

var dim: ColorRect
var fx: Control
var title_box: Control
var section_box: VBoxContainer
var role_label: Label
var name_label: Label
var finale_box: Control
var hint: Label
var faces: Array[TextureRect] = []


func start(name_text: String) -> void:
	hero_name = name_text
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	credit_lines = ["Starring: %s" % hero_name, "Made by: Love for %s" % hero_name, "Inspired by: %s" % hero_name]
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	dim = ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.1, 0.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	fx = Confetti.new()
	root.add_child(fx)

	# --- the big title
	title_box = _centered(root)
	var up := hero_name.to_upper()
	var line1 := _rich("[center][wave amp=28 freq=5.0][rainbow freq=0.22 sat=0.75 val=1.0]HAPPY BIRTHDAY[/rainbow][/wave][/center]", 118)
	title_box.get_child(0).add_child(line1)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	title_box.get_child(0).add_child(row)
	row.add_child(_face())
	row.add_child(_rich("[center][wave amp=34 freq=4.0][tornado radius=4 freq=2.0][color=#ffd23f]%s[/color][/tornado][/wave][/center]" % up, 140))
	row.add_child(_face())
	title_box.modulate.a = 0.0

	# --- credits sections
	section_box = _centered(root).get_child(0) as VBoxContainer
	section_box.get_parent().modulate.a = 0.0
	role_label = _label(section_box, 54, Color(0.75, 0.85, 1.0))
	name_label = _label(section_box, 120, Color(1.0, 0.85, 0.3))
	section_box.get_parent().name = "SectionHolder"

	# --- last wish
	finale_box = _centered(root)
	finale_box.get_child(0).add_child(_rich("[center][wave amp=18 freq=4.0][rainbow freq=0.25 sat=0.75 val=1.0]HAPPY BIRTHDAY %s![/rainbow][/wave][/center]" % up, 96))
	var thanks := _label(finale_box.get_child(0), 44, Color(1, 1, 1))
	thanks.text = "thanks for playing"
	finale_box.modulate.a = 0.0

	hint = _label(root, 26, Color(1, 1, 1, 0.7))
	hint.text = "press ENTER to skip"
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -56
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate.a = 0.0
	Sfx.set_music(false)
	Sfx.play("birthday")


func _centered(parent: Control) -> Control:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(box)
	return holder


func _rich(bb: String, font_size: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.custom_minimum_size = Vector2(300, 0)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_font_size_override("normal_font_size", font_size)
	r.add_theme_font_size_override("bold_font_size", font_size)
	r.add_theme_color_override("default_color", Color.WHITE)
	r.add_theme_color_override("font_outline_color", Color(0.12, 0.04, 0.16))
	r.add_theme_constant_override("outline_size", maxi(10, font_size / 6))
	r.text = bb
	return r


func _label(parent: Node, size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.12, 0.04, 0.16))
	l.add_theme_constant_override("outline_size", maxi(8, size_px / 6))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _face() -> TextureRect:
	var f := TextureRect.new()
	f.texture = Game.face_texture
	f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	f.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	f.custom_minimum_size = Vector2(150, 150)
	f.pivot_offset = Vector2(75, 75)
	faces.append(f)
	return f


# 0 -> 1 between a and b, 1 until c, back to 0 at d
func _env(x: float, a: float, b: float, c: float, d: float) -> float:
	if x < a or x > d:
		return 0.0
	if x < b:
		return (x - a) / (b - a)
	if x <= c:
		return 1.0
	return 1.0 - (x - c) / (d - c)


func current_section() -> int:
	for i in 3:
		var s := SECTION_START + i * SECTION_LEN
		if t >= s and t <= s + SECTION_LEN - 0.3:
			return i
	return -1


func _process(delta: float) -> void:
	if _done:
		return
	t += delta
	dim.color.a = minf(0.62, t * 0.5)
	title_box.modulate.a = _env(t, 0.2, 1.0, TITLE_END - 0.8, TITLE_END)
	for i in faces.size():
		faces[i].rotation = sin(t * 4.0 + i * PI) * 0.18
		faces[i].scale = Vector2.ONE * (1.0 + 0.08 * sin(t * 6.0 + i))
	# credit sections
	var idx := current_section()
	var hold := section_box.get_parent()
	var alpha := 0.0
	for i in 3:
		var s := SECTION_START + i * SECTION_LEN
		var e := _env(t, s, s + 0.5, s + SECTION_LEN - 0.8, s + SECTION_LEN - 0.3)
		if e > 0.0:
			var parts: PackedStringArray = credit_lines[i].split(": ")
			role_label.text = parts[0]
			name_label.text = parts[1]
			alpha = e
	hold.modulate.a = alpha
	name_label.scale = Vector2.ONE * (1.0 + 0.04 * sin(t * 5.0))
	name_label.pivot_offset = name_label.size * 0.5
	finale_box.modulate.a = _env(t, FINALE_START, FINALE_START + 0.8, END_TIME - 0.5, END_TIME)
	hint.modulate.a = clampf((t - 2.0) * 0.5, 0.0, 0.7)
	# fireworks
	_next_burst -= delta
	if _next_burst <= 0.0 and t < END_TIME - 1.0:
		_next_burst = randf_range(0.45, 0.9)
		var vp := get_viewport().get_visible_rect().size
		fx.burst(Vector2(randf_range(0.12, 0.88) * vp.x, randf_range(0.12, 0.55) * vp.y), Color.from_hsv(randf(), 0.8, 1.0))
		Sfx.play("land", randf_range(1.4, 2.0), -9.0)
	if t >= FINALE_START and t - delta < FINALE_START:
		for i in 4:
			fx.burst(Vector2(randf_range(0.2, 0.8) * 1280.0, randf_range(0.2, 0.5) * 720.0), Color.from_hsv(randf(), 0.8, 1.0), 60)
		Sfx.play("win")
	if (t > 1.5 and Input.is_action_just_pressed("confirm")) or t >= END_TIME:
		finish()


func finish() -> void:
	if _done:
		return
	_done = true
	Sfx.set_music(true)
	finished.emit()
