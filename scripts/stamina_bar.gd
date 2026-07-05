extends Control

@export var available := true:
	set(value):
		if available == value:
			return
		available = value
		_target_fill = 1.0 if available else 0.0
		_pop = 1.0

@export var empty_warning := false

const BLUE := Color(0.16, 0.72, 1.0, 1.0)
const BLUE_EDGE := Color(0.68, 0.92, 1.0, 1.0)
const GRAY := Color(0.22, 0.25, 0.31, 1.0)
const RED := Color(1.0, 0.12, 0.18, 0.48)

var _fill := 1.0
var _target_fill := 1.0
var _pop := 0.0
var _blink := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(46.0, 18.0)
	pivot_offset = custom_minimum_size * 0.5

func _process(delta: float) -> void:
	_fill = lerp(_fill, _target_fill, 1.0 - exp(-12.0 * delta))
	_pop = max(0.0, _pop - delta * 5.0)
	_blink += delta * 8.0
	scale = Vector2.ONE * (1.0 + sin(_pop * PI) * 0.08)
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var skew := h * 0.55
	var shape := PackedVector2Array([
		Vector2(skew, 0.0),
		Vector2(w, 0.0),
		Vector2(w - skew, h),
		Vector2(0.0, h),
	])

	draw_colored_polygon(shape, GRAY)

	if _fill > 0.01:
		var fw: float = maxf(skew + 1.0, w * _fill)
		var fill_shape := PackedVector2Array([
			Vector2(skew, 0.0),
			Vector2(fw, 0.0),
			Vector2(maxf(0.0, fw - skew), h),
			Vector2(0.0, h),
		])
		draw_colored_polygon(fill_shape, BLUE)
		var fill_outline := PackedVector2Array(fill_shape)
		fill_outline.append(fill_shape[0])
		draw_polyline(fill_outline, BLUE_EDGE, 1.4, true)

	var outline := PackedVector2Array(shape)
	outline.append(shape[0])
	draw_polyline(outline, Color(0.72, 0.8, 0.9, 0.38), 1.2, true)

	if empty_warning:
		var alpha: float = 0.18 + maxf(0.0, sin(_blink)) * 0.34
		draw_colored_polygon(shape, Color(RED.r, RED.g, RED.b, alpha))
