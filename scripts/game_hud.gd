extends CanvasLayer

var stamina: Control
var timer_label: Label
var death_label: Label
var switch_label: Label
var pause_panel: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build_hud()
	Global.run_stats_changed.connect(_on_stats_changed)
	_on_stats_changed(Global.run_time, Global.run_deaths, Global.run_gravity_switches)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()

func _build_hud() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	stamina = preload("res://scripts/stamina_hud.gd").new()
	root.add_child(stamina)

	var stats := HBoxContainer.new()
	stats.offset_left = 26.0
	stats.offset_top = 22.0
	stats.offset_right = 470.0
	stats.offset_bottom = 56.0
	stats.add_theme_constant_override("separation", 24)
	root.add_child(stats)

	timer_label = _make_stat_label("00:00.00")
	death_label = _make_stat_label("D 0")
	switch_label = _make_stat_label("G 0")
	stats.add_child(timer_label)
	stats.add_child(death_label)
	stats.add_child(switch_label)

	pause_panel = _make_pause_panel()
	pause_panel.visible = false
	root.add_child(pause_panel)

func _make_stat_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_override("font", load("res://assets/public/fonts/ArkitechLight-ovWKz.otf"))
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.82, 0.91, 1.0, 0.95))
	return label

func _make_pause_panel() -> Control:
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.008, 0.012, 0.02, 0.8)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -210.0
	panel.offset_top = -175.0
	panel.offset_right = 210.0
	panel.offset_bottom = 175.0
	panel.add_theme_stylebox_override("panel", _panel_style())
	overlay.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	var title := _make_title("PAUSED", 38)
	box.add_child(title)
	
	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "LEVEL %d PROTOCOL" % Global.current_level
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", load("res://assets/public/fonts/ArkitechLight-ovWKz.otf"))
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.0, 0.94, 1.0, 0.8))
	box.add_child(subtitle)
	
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(1, 8)
	box.add_child(spacer)

	box.add_child(_make_menu_button("RESUME", _toggle_pause))
	box.add_child(_make_menu_button("RESTART", func(): Global.restart_current_level()))
	box.add_child(_make_menu_button("LEVEL SELECT", func(): get_tree().change_scene_to_file("res://scenes/start_menu.tscn")))
	return overlay

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.06, 0.96)
	style.border_color = Color(0.0, 0.94, 1.0, 0.65)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 34
	style.content_margin_right = 34
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	style.shadow_color = Color(0.0, 0.94, 1.0, 0.12)
	style.shadow_size = 20
	return style

func _button_style(bg: Color, border: Color, shadow_sz := 0, shadow_col := Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 24
	style.content_margin_right = 18
	if shadow_sz > 0:
		style.shadow_color = shadow_col
		style.shadow_size = shadow_sz
	return style

func _make_title(text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", load("res://assets/public/fonts/ArkitechLight-ovWKz.otf"))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.88, 0.96, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.94, 1.0, 0.35))
	label.add_theme_constant_override("outline_size", 8)
	return label

func _make_menu_button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(260, 46)
	button.add_theme_font_override("font", load("res://assets/public/fonts/ArkitechLight-ovWKz.otf"))
	button.add_theme_font_size_override("font_size", 18)
	
	button.add_theme_stylebox_override("normal", _button_style(Color(0.03, 0.04, 0.06, 0.65), Color(0.0, 0.94, 1.0, 0.22), 6, Color(0.0, 0.94, 1.0, 0.06)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.06, 0.12, 0.20, 0.85), Color(0.0, 0.94, 1.0, 0.95), 10, Color(0.0, 0.94, 1.0, 0.18)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.02, 0.06, 0.12, 0.95), Color(0.0, 0.94, 1.0, 1.0), 4, Color(0.0, 0.94, 1.0, 0.3)))
	button.add_theme_stylebox_override("focus", _button_style(Color(0.03, 0.04, 0.06, 0.65), Color(0.0, 0.94, 1.0, 0.5)))
	button.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.0, 0.94, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
	
	var indicator := ColorRect.new()
	indicator.color = Color(0.0, 0.94, 1.0)
	indicator.custom_minimum_size = Vector2(4, 20)
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(indicator)
	
	indicator.anchor_top = 0.5
	indicator.anchor_bottom = 0.5
	indicator.offset_left = 10
	indicator.offset_top = -10
	indicator.offset_right = 14
	indicator.offset_bottom = 10
	indicator.modulate.a = 0.0
	indicator.scale.y = 0.0
	indicator.pivot_offset = Vector2(2, 10)
	
	button.pressed.connect(func():
		Global.play_sfx("click")
		callback.call()
	)
	button.mouse_entered.connect(func(): _animate_button(button, true, indicator))
	button.mouse_exited.connect(func(): _animate_button(button, false, indicator))
	return button

func _animate_button(button: Button, hover: bool, indicator: ColorRect) -> void:
	button.pivot_offset = button.size * 0.5
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.04, 1.04) if hover else Vector2.ONE, 0.14)
	
	var ind_tween := create_tween()
	ind_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	ind_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ind_tween.tween_property(indicator, "modulate:a", 1.0 if hover else 0.0, 0.14)
	ind_tween.parallel().tween_property(indicator, "scale:y", 1.0 if hover else 0.0, 0.14)
	
	if hover:
		Global.play_sfx("hover")

func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	pause_panel.visible = get_tree().paused
	Global.play_sfx("click")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if get_tree().paused else Input.MOUSE_MODE_CAPTURED)

func _on_stats_changed(time: float, deaths: int, gravity_switches: int) -> void:
	timer_label.text = Global.format_time(time)
	death_label.text = "D %d" % deaths
	switch_label.text = "G %d" % gravity_switches

