extends Control
# Party layer for the credits: falling confetti and beer bottles, plus firework bursts.

const COLORS := [Color(1.0, 0.3, 0.4), Color(1.0, 0.8, 0.2), Color(0.3, 0.85, 0.5), Color(0.3, 0.6, 1.0), Color(0.85, 0.4, 1.0), Color(1.0, 0.55, 0.15)]

var pieces: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var active := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rng.randomize()
	for i in 150:
		pieces.append(_new_piece(true))


func _new_piece(anywhere: bool) -> Dictionary:
	var w := maxf(size.x, 1280.0)
	var h := maxf(size.y, 720.0)
	var kind := 2 if rng.randf() < 0.12 else rng.randi() % 2     # a few of the pieces are beer bottles
	return {
		"pos": Vector2(rng.randf() * w, rng.randf() * h if anywhere else -30.0),
		"vel": Vector2(rng.randf_range(-40.0, 40.0), rng.randf_range(90.0, 230.0)),
		"rot": rng.randf() * TAU,
		"spin": rng.randf_range(-5.0, 5.0),
		"size": rng.randf_range(9.0, 18.0) * (1.8 if kind == 2 else 1.0),
		"color": COLORS[rng.randi() % COLORS.size()],
		"kind": kind,
		"phase": rng.randf() * TAU,
	}


func burst(at: Vector2, color: Color, count := 46) -> void:
	for i in count:
		var a := TAU * i / count + rng.randf_range(-0.05, 0.05)
		var sp := rng.randf_range(160.0, 340.0)
		sparks.append({"pos": at, "vel": Vector2(cos(a), sin(a)) * sp, "life": rng.randf_range(0.9, 1.4), "age": 0.0,
			"color": color.lerp(Color.WHITE, rng.randf() * 0.4)})


func _process(delta: float) -> void:
	var h := maxf(size.y, 720.0)
	for p in pieces:
		p.phase += delta * 3.0
		p.pos += (p.vel + Vector2(sin(p.phase) * 35.0, 0.0)) * delta
		p.rot += p.spin * delta
		if p.pos.y > h + 40.0 and active:
			var np := _new_piece(false)
			p.pos = np.pos
			p.vel = np.vel
	for s in sparks:
		s.age += delta
		s.vel += Vector2(0, 220.0) * delta
		s.vel *= 1.0 - 0.9 * delta
		s.pos += s.vel * delta
	sparks = sparks.filter(func(s): return s.age < s.life)
	queue_redraw()


func _draw() -> void:
	for p in pieces:
		draw_set_transform(p.pos, p.rot, Vector2.ONE)
		var sz: float = p.size
		match int(p.kind):
			0:
				draw_rect(Rect2(-sz * 0.5, -sz * 0.25, sz, sz * 0.5), p.color)
			1:
				draw_circle(Vector2.ZERO, sz * 0.35, p.color)
			_:
				_bottle(sz)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for s in sparks:
		var a: float = 1.0 - s.age / s.life
		var c: Color = s.color
		c.a = a
		draw_circle(s.pos, 4.0 * a + 1.5, c)


func _bottle(sz: float) -> void:
	var w := sz * 0.36
	var pts := PackedVector2Array([
		Vector2(-w, -sz * 0.05), Vector2(-w, sz * 0.5), Vector2(w, sz * 0.5), Vector2(w, -sz * 0.05),
		Vector2(w * 0.35, -sz * 0.25), Vector2(w * 0.35, -sz * 0.5), Vector2(-w * 0.35, -sz * 0.5), Vector2(-w * 0.35, -sz * 0.25)])
	draw_colored_polygon(pts, Color(0.5, 0.25, 0.07))
	draw_rect(Rect2(-w, sz * 0.12, w * 2.0, sz * 0.2), Color(0.96, 0.92, 0.78))
	draw_rect(Rect2(-w * 0.4, -sz * 0.56, w * 0.8, sz * 0.1), Color(1.0, 0.8, 0.2))
