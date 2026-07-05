extends CanvasLayer

var stats: Dictionary

func setup(new_stats: Dictionary) -> void:
	stats = new_stats

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	Global.play_sfx("complete")
	_build()

func _build() -> void:
	var level := int(stats.get("level", Global.current_level))
	var is_game_complete := level >= Global.MAX_LEVEL

	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.005, 0.008, 0.015, 0.85)
	add_child(overlay)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -280.0
	panel.offset_top = -240.0
	panel.offset_right = 280.0
	panel.offset_bottom = 240.0
	panel.add_theme_stylebox_override("panel", _panel_style())
	overlay.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	panel.add_child(box)

	var title_text := "SYSTEM CLEANSED" if is_game_complete else "LEVEL COMPLETED"
	var title_color := Color(0.0, 1.0, 0.5) if is_game_complete else Color(0.0, 0.94, 1.0)
	
	var title_label := _make_label(title_text, 34, title_color)
	box.add_child(title_label)
	
	var subtitle_text := "ALL PROTOCOLS SUCCESSFUL" if is_game_complete else "SECTOR %d SECURED" % level
	var subtitle_color := Color(0.85, 0.95, 1.0, 0.8)
	box.add_child(_make_label(subtitle_text, 14, subtitle_color))

	# Divider line
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(1, 1.5)
	divider.color = Color(title_color.r, title_color.g, title_color.b, 0.25)
	box.add_child(divider)

	# Stats grid
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 80)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(grid)
	
	_add_stat_row(grid, "COMPLETION TIME", Global.format_time(float(stats["time"])))
	_add_stat_row(grid, "DEATHS", str(int(stats["deaths"])))
	_add_stat_row(grid, "GRAVITY SWITCHES", str(int(stats["gravity_switches"])))
	
	# Divider
	var grid_divider := Control.new()
	grid_divider.custom_minimum_size = Vector2(1, 4)
	box.add_child(grid_divider)
	
	var score_grid := GridContainer.new()
	score_grid.columns = 2
	score_grid.add_theme_constant_override("h_separation", 80)
	score_grid.add_theme_constant_override("v_separation", 10)
	score_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(score_grid)
	
	_add_stat_row(score_grid, "SECTOR SCORE", str(int(stats["score"])), Color(0.0, 0.94, 1.0))
	_add_stat_row(score_grid, "PERSONAL BEST", str(int(stats["best_score"])), Color(0.85, 0.95, 1.0))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(1, 12)
	box.add_child(spacer)

	# Action buttons
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)

	if level < Global.MAX_LEVEL:
		buttons.add_child(_button("NEXT", func(): Global.load_level(level + 1)))
	buttons.add_child(_button("RETRY", func(): Global.restart_current_level()))
	buttons.add_child(_button("MENU", func(): get_tree().change_scene_to_file("res://scenes/start_menu.tscn")))

	# Animation Entrance
	overlay.modulate.a = 0.0
	panel.position.y += 24.0
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.32)
	tween.parallel().tween_property(panel, "position:y", panel.position.y - 24.0, 0.32)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.06, 0.98)
	style.border_color = Color(0.0, 0.94, 1.0, 0.68)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 38
	style.content_margin_right = 38
	style.content_margin_top = 34
	style.content_margin_bottom = 34
	style.shadow_color = Color(0.0, 0.94, 1.0, 0.15)
	style.shadow_size = 24
	return style

func _button_style(bg: Color, border: Color, shadow_sz := 0, shadow_col := Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 22
	style.content_margin_right = 16
	if shadow_sz > 0:
		style.shadow_color = shadow_col
		style.shadow_size = shadow_sz
	return style

func _add_stat_row(grid: GridContainer, name: String, value: String, name_color := Color(0.58, 0.68, 0.78)) -> void:
	var name_label := _make_label(name, 12, name_color)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	grid.add_child(name_label)
	
	var value_label := _make_label(value, 15, Color(0.92, 0.96, 1.0))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(value_label)

func _make_label(text_value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", load("res://assets/public/fonts/ArkitechLight-ovWKz.otf"))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if size >= 24:
		label.add_theme_color_override("font_outline_color", Color(color.r, color.g, color.b, 0.35))
		label.add_theme_constant_override("outline_size", 8)
	return label

func _button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(130, 44)
	button.add_theme_font_override("font", load("res://assets/public/fonts/ArkitechLight-ovWKz.otf"))
	button.add_theme_font_size_override("font_size", 16)
	
	button.add_theme_stylebox_override("normal", _button_style(Color(0.03, 0.04, 0.06, 0.65), Color(0.0, 0.94, 1.0, 0.22), 4, Color(0.0, 0.94, 1.0, 0.06)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.06, 0.12, 0.20, 0.85), Color(0.0, 0.94, 1.0, 0.95), 8, Color(0.0, 0.94, 1.0, 0.16)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.02, 0.06, 0.12, 0.95), Color(0.0, 0.94, 1.0, 1.0), 4, Color(0.0, 0.94, 1.0, 0.25)))
	button.add_theme_stylebox_override("focus", _button_style(Color(0.03, 0.04, 0.06, 0.65), Color(0.0, 0.94, 1.0, 0.5)))
	button.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.0, 0.94, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))

	var indicator := ColorRect.new()
	indicator.color = Color(0.0, 0.94, 1.0)
	indicator.custom_minimum_size = Vector2(3, 18)
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(indicator)
	
	indicator.anchor_top = 0.5
	indicator.anchor_bottom = 0.5
	indicator.offset_left = 8
	indicator.offset_top = -9
	indicator.offset_right = 11
	indicator.offset_bottom = 9
	indicator.modulate.a = 0.0
	indicator.scale.y = 0.0
	indicator.pivot_offset = Vector2(1.5, 9)

	button.pressed.connect(func():
		Global.play_sfx("click")
		callback.call()
	)
	button.mouse_entered.connect(func(): _hover(button, true, indicator))
	button.mouse_exited.connect(func(): _hover(button, false, indicator))
	return button

func _hover(button: Button, hovered: bool, indicator: ColorRect) -> void:
	button.pivot_offset = button.size * 0.5
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(button, "scale", Vector2(1.05, 1.05) if hovered else Vector2.ONE, 0.12)
	
	var ind_tween := create_tween()
	ind_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	ind_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ind_tween.tween_property(indicator, "modulate:a", 1.0 if hovered else 0.0, 0.12)
	ind_tween.parallel().tween_property(indicator, "scale:y", 1.0 if hovered else 0.0, 0.12)

	if hovered:
		Global.play_sfx("hover")
