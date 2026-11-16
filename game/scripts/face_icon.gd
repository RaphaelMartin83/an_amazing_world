extends Control
# Draws the hero's cartoon face (used in the HUD and on the extra-life crates).

var cfg: Dictionary


func _draw() -> void:
	if cfg.is_empty():
		return
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.4
	var ol := Color(0.09, 0.05, 0.08)
	var lw := maxf(2.0, r * 0.09)
	var skin: Color = cfg.skin
	var hair: Color = cfg.hair_color
	var style := str(cfg.hair_style)
	# hair back (long)
	if style == "long":
		draw_rect(Rect2(c + Vector2(-r * 1.08, -r * 0.4), Vector2(r * 2.16, r * 1.7)), hair)
	# ears
	for sx in [-1.0, 1.0]:
		draw_circle(c + Vector2(sx * r * 1.0, r * 0.05), r * 0.2, skin)
		draw_arc(c + Vector2(sx * r * 1.0, r * 0.05), r * 0.2, 0, TAU, 20, ol, lw * 0.6)
	# head
	draw_circle(c, r, skin)
	# beard
	var beard := str(cfg.beard)
	if beard == "full":
		draw_circle(c + Vector2(0, r * 0.42), r * 0.78, hair)
		draw_circle(c + Vector2(0, r * 0.1), r * 0.98, skin)
		draw_rect(Rect2(c + Vector2(-r * 0.9, r * 0.05), Vector2(r * 1.8, r * 0.2)), skin)
	elif beard == "stubble":
		draw_circle(c + Vector2(0, r * 0.45), r * 0.7, skin.lerp(hair, 0.4))
	elif beard == "goatee":
		draw_circle(c + Vector2(0, r * 0.78), r * 0.2, hair)
	draw_arc(c, r, 0, TAU, 40, ol, lw)
	# hair: a cap on the top of the head with a curved hairline well above the eyes
	match style:
		"short", "long", "curly":
			var pts := PackedVector2Array()
			for i in 25:
				var a := PI + PI * i / 24.0
				pts.append(c + Vector2(cos(a), sin(a)) * r * 1.04)
			for i in 25:
				var x := lerpf(1.0, -1.0, i / 24.0)
				pts.append(c + Vector2(x * r * 0.99, -r * (0.52 - 0.22 * x * x)))
			draw_colored_polygon(pts, hair)
			draw_polyline(pts, ol, lw)
			if style == "curly":
				for i in 9:
					var a2 := lerpf(PI * 1.0, PI * 2.0, i / 8.0)
					draw_circle(c + Vector2(cos(a2), sin(a2)) * r * 1.0, r * 0.28, hair)
		"messy":
			var mp2 := PackedVector2Array()
			for i in 25:
				var a4 := PI + PI * i / 24.0
				mp2.append(c + Vector2(cos(a4), sin(a4)) * r * 1.06)
			# side-swept hairline: low on the right, higher on the left
			for i in 25:
				var x3 := lerpf(1.0, -1.0, i / 24.0)
				mp2.append(c + Vector2(x3 * r * 0.95, -r * (0.56 - 0.22 * x3 * x3 + 0.12 * x3)))
			draw_colored_polygon(mp2, hair)
			draw_polyline(mp2, ol, lw)
			for i in 5:
				var tx := lerpf(-0.6, 0.6, i / 4.0)
				var base := c + Vector2(tx * r, -r * (0.92 - 0.2 * tx * tx))
				draw_colored_polygon(PackedVector2Array([base + Vector2(-r * 0.2, 0), base + Vector2(r * (0.1 + tx * 0.2), -r * 0.26), base + Vector2(r * 0.2, 0)]), hair)
		"spiky":
			for i in 7:
				var a := lerpf(PI * 1.1, PI * 1.9, i / 6.0)
				var tip := c + Vector2(cos(a), sin(a)) * r * 1.5
				var b0 := c + Vector2(cos(a - 0.24), sin(a - 0.24)) * r * 1.0
				var b1 := c + Vector2(cos(a + 0.24), sin(a + 0.24)) * r * 1.0
				draw_colored_polygon(PackedVector2Array([b0, tip, b1]), hair)
			var pts2 := PackedVector2Array()
			for i in 25:
				var a3 := PI + PI * i / 24.0
				pts2.append(c + Vector2(cos(a3), sin(a3)) * r * 1.03)
			for i in 25:
				var x2 := lerpf(1.0, -1.0, i / 24.0)
				pts2.append(c + Vector2(x2 * r * 0.99, -r * (0.56 - 0.2 * x2 * x2)))
			draw_colored_polygon(pts2, hair)
		"buzz":
			draw_arc(c, r * 0.94, PI * 1.1, PI * 1.9, 24, hair, r * 0.2)
		_:
			pass
	# eyes
	for sx in [-1.0, 1.0]:
		var ec := c + Vector2(sx * r * 0.38, -r * 0.02)
		draw_circle(ec, r * 0.24, Color.WHITE)
		draw_arc(ec, r * 0.24, 0, TAU, 20, ol, lw * 0.7)
		draw_circle(ec + Vector2(0, r * 0.02), r * 0.14, cfg.eye_color)
		draw_circle(ec + Vector2(0, r * 0.02), r * 0.075, ol)
		draw_circle(ec + Vector2(r * 0.04, -r * 0.05), r * 0.04, Color.WHITE)
		draw_line(ec + Vector2(-r * 0.2, -r * 0.34), ec + Vector2(r * 0.2, -r * 0.4 - sx * r * 0.04), hair, lw * 1.0)
	# nose
	draw_circle(c + Vector2(0, r * 0.2), r * 0.1, skin.darkened(0.1))
	# mouth
	var mp := PackedVector2Array([
		c + Vector2(-r * 0.4, r * 0.42), c + Vector2(r * 0.4, r * 0.42),
		c + Vector2(r * 0.28, r * 0.66), c + Vector2(0, r * 0.74), c + Vector2(-r * 0.28, r * 0.66)])
	draw_colored_polygon(mp, Color(0.4, 0.07, 0.1))
	draw_rect(Rect2(c + Vector2(-r * 0.36, r * 0.42), Vector2(r * 0.72, r * 0.1)), Color.WHITE)
	draw_polyline(PackedVector2Array([mp[0], mp[4], mp[3], mp[2], mp[1], mp[0]]), ol, lw * 0.6)
	if bool(cfg.moustache):
		draw_arc(c + Vector2(-r * 0.2, r * 0.36), r * 0.22, PI * 0.9, PI * 1.9, 12, hair, r * 0.1)
		draw_arc(c + Vector2(r * 0.2, r * 0.36), r * 0.22, PI * 1.1, PI * 2.1, 12, hair, r * 0.1)
	# glasses
	if bool(cfg.glasses):
		for sx in [-1.0, 1.0]:
			draw_arc(c + Vector2(sx * r * 0.38, -r * 0.02), r * 0.31, 0, TAU, 24, cfg.glasses_color, lw * 1.0)
		draw_line(c + Vector2(-r * 0.08, -r * 0.04), c + Vector2(r * 0.08, -r * 0.04), cfg.glasses_color, lw)
	# cap / headband
	match str(cfg.accessory):
		"cap":
			draw_circle(c + Vector2(0, -r * 0.35), r * 1.02, cfg.accessory_color)
			draw_rect(Rect2(c + Vector2(-r * 1.02, -r * 0.35), Vector2(r * 2.04, r * 0.22)), cfg.accessory_color)
			draw_rect(Rect2(c + Vector2(-r * 0.7, -r * 0.2), Vector2(r * 1.4, r * 0.12)), cfg.accessory_color.darkened(0.25))
		"headband":
			draw_rect(Rect2(c + Vector2(-r * 0.98, -r * 0.55), Vector2(r * 1.96, r * 0.2)), cfg.accessory_color)
