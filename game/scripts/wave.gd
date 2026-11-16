extends Node3D
# A tidal wave that periodically rises across the path. Foam ripples warn you first; cross while it's calm.
# The node's origin sits on the floor, in the middle of the band the wave covers.

const T = preload("res://scripts/toon.gd")
const IDLE := 2.4
const WARN := 1.0
const RISE := 0.35
const HOLD := 0.5
const FALL := 0.5
const PERIOD := IDLE + WARN + RISE + HOLD + FALL

var width := 10.0
var thickness := 3.2
var max_h := 2.6
var phase := 0.0
var t := 0.0
var water: MeshInstance3D
var foam: MeshInstance3D
var warn: MeshInstance3D
var _was_rising := false


func _ready() -> void:
	add_to_group("wave")
	t = phase
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.1, 0.65, 0.85, 0.82)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.1
	wm.emission_enabled = true
	wm.emission = Color(0.05, 0.4, 0.55)
	wm.emission_energy_multiplier = 0.7
	water = T.box(self, Vector3.ONE, Vector3.ZERO, wm)
	water.scale = Vector3(width + 1.0, 0.01, thickness)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	foam = T.box(self, Vector3(width + 1.4, 0.35, thickness + 0.5), Vector3.ZERO, T.emissive(Color(0.95, 1.0, 1.0), 0.6))
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var wr := StandardMaterial3D.new()
	wr.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wr.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wr.albedo_color = Color(0.85, 1.0, 1.0, 0.0)
	warn = T.box(self, Vector3(width, 0.04, thickness), Vector3(0, 0.05, 0), wr)
	warn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func state() -> String:
	var m := fposmod(t, PERIOD)
	if m < IDLE:
		return "idle"
	if m < IDLE + WARN:
		return "warn"
	if m < IDLE + WARN + RISE:
		return "rise"
	if m < IDLE + WARN + RISE + HOLD:
		return "hold"
	return "fall"


func height() -> float:
	var m := fposmod(t, PERIOD)
	if m < IDLE + WARN:
		return 0.0
	m -= IDLE + WARN
	if m < RISE:
		return max_h * m / RISE
	m -= RISE
	if m < HOLD:
		return max_h
	m -= HOLD
	return max_h * (1.0 - m / FALL)


# True when there's enough calm left to run across.
func is_safe() -> bool:
	var m := fposmod(t, PERIOD)
	return m < IDLE and IDLE - m >= 1.3


func _physics_process(delta: float) -> void:
	t += delta
	var h := height()
	var st := state()
	water.visible = h > 0.02
	water.scale.y = maxf(h, 0.01)
	water.position.y = h * 0.5
	foam.visible = h > 0.02
	foam.position.y = h
	var wm: StandardMaterial3D = warn.material_override
	wm.albedo_color.a = (0.35 + 0.35 * sin(t * 18.0)) if st == "warn" else 0.0
	if st == "rise" and not _was_rising:
		Sfx.play("rumble", 1.2)
	_was_rising = st == "rise"
	if h > 0.25:
		var pl: Node3D = Game.player
		if pl and is_instance_valid(pl) and not pl.dead:
			var d := pl.global_position - global_position
			if absf(d.z) < thickness * 0.5 + 0.2 and absf(d.x) < width * 0.5 + 0.6 and d.y < h - 0.2 and d.y > -1.0:
				pl.hurt()
