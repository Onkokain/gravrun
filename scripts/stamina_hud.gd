extends Control

const BAR_COUNT := 5
const RECHARGE_SECONDS := 5.0
const BAR_WIDTH := 46.0
const BAR_HEIGHT := 18.0
const BAR_SPACING := BAR_WIDTH * 0.5

var bars: Array[Control] = []
var countdown_label: Label
var _charges := BAR_COUNT
var _recharge_remaining := 0.0

func _ready() -> void:
	add_to_group("stamina_hud")
	anchor_left = 1.0
	anchor_right = 1.0
	offset_left = -360.0
	offset_top = 24.0
	offset_right = -28.0
	offset_bottom = 84.0
	modulate.a = 0.0
	position.y -= 16.0
	_build()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.35)
	tween.parallel().tween_property(self, "position:y", position.y + 16.0, 0.35)

func _process(delta: float) -> void:
	if _charges < BAR_COUNT:
		_recharge_remaining -= delta
		if _recharge_remaining <= 0.0:
			_charges += 1
			_recharge_remaining = RECHARGE_SECONDS if _charges < BAR_COUNT else 0.0
			Global.play_sfx("regen")
			_update_bars()

	_update_countdown()

func try_consume() -> bool:
	if _charges <= 0:
		_pulse_empty()
		return false

	_charges -= 1
	if _charges < BAR_COUNT and _recharge_remaining <= 0.0:
		_recharge_remaining = RECHARGE_SECONDS
	_update_bars()
	return true

func refill() -> void:
	_charges = BAR_COUNT
	_recharge_remaining = 0.0
	_update_bars()
	_update_countdown()

func _build() -> void:
	var row := HBoxContainer.new()
	row.anchor_left = 1.0
	row.anchor_right = 1.0
	row.offset_left = -(BAR_WIDTH * BAR_COUNT + BAR_SPACING * (BAR_COUNT - 1))
	row.offset_right = 0.0
	row.offset_bottom = BAR_HEIGHT
	row.add_theme_constant_override("separation", int(BAR_SPACING))
	add_child(row)

	for i in range(BAR_COUNT):
		var bar := Control.new()
		bar.set_script(preload("res://scripts/stamina_bar.gd"))
		bar.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
		row.add_child(bar)
		bars.append(bar)

	countdown_label = Label.new()
	countdown_label.anchor_left = 1.0
	countdown_label.anchor_right = 1.0
	countdown_label.offset_left = -160.0
	countdown_label.offset_top = 25.0
	countdown_label.offset_right = 0.0
	countdown_label.offset_bottom = 52.0
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	countdown_label.add_theme_font_override("font", load("res://assets/public/fonts/ArkitechLight-ovWKz.otf"))
	countdown_label.add_theme_font_size_override("font_size", 18)
	countdown_label.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0, 0.9))
	add_child(countdown_label)
	_update_bars()

func _update_bars() -> void:
	var empty := _charges == 0
	for i in bars.size():
		bars[i].available = i < _charges
		bars[i].empty_warning = empty

func _update_countdown() -> void:
	if _charges >= BAR_COUNT:
		countdown_label.text = "READY"
	else:
		countdown_label.text = "%.1f" % max(0.0, _recharge_remaining)

func _pulse_empty() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.04, 1.04), 0.08)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12)
