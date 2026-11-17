extends CanvasLayer
# The opening: two cards on black.   "<NAME> INTERACTIVE presents"   then   "A <NAME> STORY".
# Each text types itself in; any key / click / button skips. Like the credits, everything is a function of `t`.

signal finished

const CARD1_IN := 0.6
const CARD1_HOLD := 3.7
const CARD1_OUT := 4.5
const CARD2_IN := 5.1
const CARD2_HOLD := 8.3
const CARD2_OUT := 9.2
const END_TIME := 9.7

var t := 0.0
var hero_name := ""
var card_texts: Array[String] = []        # the visible text of each card (read by the tests)
var _done := false
var _sound1 := false
var _sound2 := false

var card1: Control
var card2: Control
var logo: TextureRect
var title1: RichTextLabel
var presents: Label
var title2: RichTextLabel
var flare: ColorRect
var hint: Label


func start(name_text: String) -> void:
	hero_name = name_text
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	var up := hero_name.to_upper()
	card_texts = ["%s INTERACTIVE presents" % up, "A %s STORY" % up]
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var black := ColorRect.new()
	black.name = "Black"
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(black)

	# --- card 1: the studio logo
	card1 = _centered(root)
	var box1: VBoxContainer = card1.get_child(0)
	logo = TextureRect.new()
	logo.texture = Game.face_texture
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(150, 150)
	logo.pivot_offset = Vector2(75, 75)
	box1.add_child(logo)
	title1 = _rich("[center][color=#ffd23f]%s[/color] [color=#ffffff]INTERACTIVE[/color][/center]" % up, 88)
	box1.add_child(title1)
	presents = Label.new()
	presents.text = "presents"
	presents.add_theme_font_size_override("font_size", 46)
	presents.add_theme_color_override("font_color", Color(0.82, 0.86, 1.0))
	presents.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box1.add_child(presents)
	card1.modulate.a = 0.0

	# --- card 2: the title card
	card2 = _centered(root)
	title2 = _rich("[center][color=#ffffff]A[/color] [color=#ffd23f]%s[/color] [color=#ffffff]STORY[/color][/center]" % up, 104)
	card2.get_child(0).add_child(title2)
	card2.modulate.a = 0.0
	flare = ColorRect.new()                                # a light streak that sweeps across the card
	flare.color = Color(1.0, 0.95, 0.75, 0.0)
	flare.size = Vector2(160, 6)
	flare.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flare)

	hint = Label.new()
	hint.text = "press any key to skip"
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -50
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate.a = 0.0
	root.add_child(hint)
	title1.visible_ratio = 0.0
	title2.visible_ratio = 0.0
	presents.visible_ratio = 0.0


func _centered(parent: Control) -> Control:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(box)
	return holder


func _rich(bb: String, font_size: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_font_size_override("normal_font_size", font_size)
	r.add_theme_color_override("default_color", Color.WHITE)
	r.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.02))
	r.add_theme_constant_override("outline_size", maxi(8, font_size / 8))
	r.text = bb
	return r


func _env(x: float, a: float, b: float, c: float, d: float) -> float:
	if x < a or x > d:
		return 0.0
	if x < b:
		return (x - a) / (b - a)
	if x <= c:
		return 1.0
	return 1.0 - (x - c) / (d - c)


func _process(delta: float) -> void:
	if _done:
		return
	t += delta
	var a1 := _env(t, CARD1_IN, CARD1_IN + 0.5, CARD1_HOLD, CARD1_OUT)
	var a2 := _env(t, CARD2_IN, CARD2_IN + 0.5, CARD2_HOLD, CARD2_OUT)
	card1.modulate.a = a1
	card2.modulate.a = a2
	# the texts type themselves in
	title1.visible_ratio = clampf((t - CARD1_IN) / 0.9, 0.0, 1.0)
	presents.visible_ratio = clampf((t - CARD1_IN - 1.0) / 0.6, 0.0, 1.0)
	title2.visible_ratio = clampf((t - CARD2_IN) / 1.0, 0.0, 1.0)
	# the logo pops in with an overshoot and then wobbles gently
	var x := clampf((t - CARD1_IN) / 0.7, 0.0, 1.0) - 1.0
	var pop := 1.0 + 2.70158 * x * x * x + 1.70158 * x * x            # ease-out-back: overshoots, then settles at 1
	logo.scale = Vector2.ONE * maxf(pop, 0.01) * (1.0 + 0.03 * sin(t * 4.0))
	logo.rotation = sin(t * 3.0) * 0.08
	# the title card zooms out very slowly; a light streak sweeps across it
	card2.pivot_offset = Vector2(640, 360)
	card2.scale = Vector2.ONE * (1.05 - 0.05 * clampf((t - CARD2_IN) / 4.0, 0.0, 1.0))
	var sweep := clampf((t - (CARD2_IN + 0.9)) / 1.3, 0.0, 1.0)
	flare.position = Vector2(lerpf(-200.0, 1320.0, sweep), 360.0 - 3.0)
	flare.color.a = sin(sweep * PI) * 0.8 * a2
	hint.modulate.a = clampf((t - 1.2) * 0.5, 0.0, 0.5)
	if t >= CARD1_IN and not _sound1:
		_sound1 = true
		Sfx.play("checkpoint")
	if t >= CARD2_IN and not _sound2:
		_sound2 = true
		Sfx.play("win")
	if t >= END_TIME:
		finish()


func _input(event: InputEvent) -> void:
	if _done or t < 0.5:
		return
	if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventJoypadButton and event.pressed):
		get_viewport().set_input_as_handled()
		finish()


func finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
