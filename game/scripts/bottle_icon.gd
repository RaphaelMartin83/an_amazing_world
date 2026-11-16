extends Control
# A little beer-bottle icon for the HUD.


func _draw() -> void:
	var s := size
	var ol := Color(0.09, 0.05, 0.08)
	var cx := s.x * 0.5
	var pts := PackedVector2Array([
		Vector2(cx - s.x * 0.30, s.y * 0.44), Vector2(cx - s.x * 0.30, s.y * 0.95), Vector2(cx + s.x * 0.30, s.y * 0.95),
		Vector2(cx + s.x * 0.30, s.y * 0.44), Vector2(cx + s.x * 0.11, s.y * 0.24), Vector2(cx + s.x * 0.11, s.y * 0.1),
		Vector2(cx - s.x * 0.11, s.y * 0.1), Vector2(cx - s.x * 0.11, s.y * 0.24)])
	draw_colored_polygon(pts, Color(0.50, 0.25, 0.07))
	draw_rect(Rect2(cx - s.x * 0.30, s.y * 0.56, s.x * 0.6, s.y * 0.24), Color(0.96, 0.92, 0.78))
	draw_rect(Rect2(cx - s.x * 0.14, s.y * 0.04, s.x * 0.28, s.y * 0.08), Color(1.0, 0.8, 0.2))
	draw_line(Vector2(cx - s.x * 0.2, s.y * 0.5), Vector2(cx - s.x * 0.2, s.y * 0.9), Color(1, 1, 1, 0.45), 2.0)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, ol, 3.0)
	draw_rect(Rect2(cx - s.x * 0.14, s.y * 0.04, s.x * 0.28, s.y * 0.08), ol, false, 2.0)
