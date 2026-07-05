extends Control

const FONT := preload("res://assets/public/fonts/ArkitechLight-ovWKz.otf")
const STAR_SHADER := preload("res://shaders/stars.gdshader")
const GLOW_SHADER := preload("res://shaders/start_menu.gdshader")

var content: Control
var panels_parent: Control
var main_panel: VBoxContainer
var level_panel: VBoxContainer
var settings_panel: VBoxContainer

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_show_panel(main_panel, false)

func _build() -> void:
	_build_background()

	content = MarginContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("margin_left", 80)
	content.add_theme_constant_override("margin_right", 80)
	content.add_theme_constant_override("margin_top", 60)
	content.add_theme_constant_override("margin_bottom", 60)
	add_child(content)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 24)
	content.add_child(layout)

	# Title block
	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 4)
	layout.add_child(title_box)

	var title := Label.new()
	title.text = "GRAVRUN"
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", Color(0.9, 0.97, 1.0))
	# Holographic glow outline
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.94, 1.0, 0.4))
	title.add_theme_constant_override("outline_size", 12)
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "GRAVITY PARKOUR PROTOCOL v2.0"
	subtitle.add_theme_font_override("font", FONT)
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.0, 0.94, 1.0, 0.85))
	title_box.add_child(subtitle)

	# Line divider
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(1, 2)
	divider.color = Color(0.0, 0.94, 1.0, 0.25)
	layout.add_child(divider)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(1, 16)
	layout.add_child(spacer)

	# Parent to hold all menu panels for clean slide animations
	panels_parent = Control.new()
	panels_parent.custom_minimum_size = Vector2(500, 400)
	layout.add_child(panels_parent)

	main_panel = _make_panel()
	level_panel = _make_panel()
	settings_panel = _make_panel()

	panels_parent.add_child(main_panel)
	panels_parent.add_child(level_panel)
	panels_parent.add_child(settings_panel)

	_build_main_panel()
	_build_level_panel()
	_build_settings_panel()

func _build_background() -> void:
	var base := ColorRect.new()
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.color = Color(0.012, 0.016, 0.027)
	add_child(base)

	var stars := ColorRect.new()
	stars.set_anchors_preset(Control.PRESET_FULL_RECT)
	var star_mat := ShaderMaterial.new()
	star_mat.shader = STAR_SHADER
	star_mat.set_shader_parameter("sky_color", Color(0.01, 0.013, 0.022, 1.0))
	star_mat.set_shader_parameter("star_density", 360.0)
	star_mat.set_shader_parameter("star_threshold", 0.993)
	stars.material = star_mat
	add_child(stars)

	var glow := ColorRect.new()
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	var glow_mat := ShaderMaterial.new()
	glow_mat.shader = GLOW_SHADER
	glow_mat.set_shader_parameter("stretch", Vector2(1.8, 0.9))
	glow_mat.set_shader_parameter("intensity", 0.8)
	glow.material = glow_mat
	glow.modulate = Color(0.85, 0.95, 1.0, 0.5)
	add_child(glow)

func _make_panel() -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_constant_override("separation", 18)
	return panel

func _build_main_panel() -> void:
	main_panel.add_child(_make_button("PLAY", func(): _show_panel(level_panel)))
	main_panel.add_child(_make_button("SETTINGS", func(): _show_panel(settings_panel)))
	main_panel.add_child(_make_button("QUIT", func(): get_tree().quit()))

func _build_level_panel() -> void:
	level_panel.add_child(_make_section_label("LEVEL SELECTION"))

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	level_panel.add_child(grid)

	var max_levels := int(Global.MAX_LEVEL) if Global else 10
	for level in range(1, max_levels + 1):
		var level_number := level
		var button := _make_level_button(level_number)
		grid.add_child(button)

	var back_btn := _make_button("BACK", func(): _show_panel(main_panel))
	back_btn.custom_minimum_size = Vector2(240, 48)
	level_panel.add_child(back_btn)

func _build_settings_panel() -> void:
	settings_panel.add_child(_make_section_label("SETTINGS"))

	# Audio Volume Container
	var vol_box := VBoxContainer.new()
	vol_box.add_theme_constant_override("separation", 8)
	settings_panel.add_child(vol_box)

	var vol_label := Label.new()
	vol_label.text = "MASTER VOLUME"
	vol_label.add_theme_font_override("font", FONT)
	vol_label.add_theme_font_size_override("font_size", 14)
	vol_label.add_theme_color_override("font_color", Color(0.6, 0.72, 0.8))
	vol_box.add_child(vol_label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	# Get current Master bus volume
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx != -1:
		slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus_idx))
	else:
		slider.value = 0.7
	slider.custom_minimum_size = Vector2(340, 24)
	slider.value_changed.connect(_on_volume_changed)
	vol_box.add_child(slider)

	# Fullscreen Checkbox Container
	var fs_box := HBoxContainer.new()
	fs_box.add_theme_constant_override("separation", 16)
	settings_panel.add_child(fs_box)

	var fs_checkbox := CheckButton.new()
	fs_checkbox.text = "FULLSCREEN"
	fs_checkbox.add_theme_font_override("font", FONT)
	fs_checkbox.add_theme_font_size_override("font_size", 14)
	fs_checkbox.add_theme_color_override("font_color", Color(0.6, 0.72, 0.8))
	fs_checkbox.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	fs_checkbox.toggled.connect(_on_fullscreen_toggled)
	fs_box.add_child(fs_checkbox)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(1, 16)
	settings_panel.add_child(spacer)

	var back_btn := _make_button("BACK", func(): _show_panel(main_panel))
	back_btn.custom_minimum_size = Vector2(240, 48)
	settings_panel.add_child(back_btn)

func _on_volume_changed(value: float) -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx != -1:
		var db := linear_to_db(value)
		AudioServer.set_bus_volume_db(bus_idx, db)
		AudioServer.set_bus_mute(bus_idx, value <= 0.01)
	if Global:
		Global.play_sfx("hover")

func _on_fullscreen_toggled(button_pressed: bool) -> void:
	if Global:
		Global.play_sfx("click")
	if button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _make_section_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.0, 0.94, 1.0))
	return label

func _make_button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(340, 52)
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 20)
	
	# Styled flat buttons with neon glow shadows
	button.add_theme_stylebox_override("normal", _button_style(Color(0.03, 0.04, 0.06, 0.65), Color(0.0, 0.94, 1.0, 0.22), 6, Color(0.0, 0.94, 1.0, 0.06)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.06, 0.12, 0.20, 0.85), Color(0.0, 0.94, 1.0, 0.9), 12, Color(0.0, 0.94, 1.0, 0.22)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.02, 0.06, 0.12, 0.95), Color(0.0, 0.94, 1.0, 1.0), 4, Color(0.0, 0.94, 1.0, 0.3)))
	button.add_theme_stylebox_override("focus", _button_style(Color(0.03, 0.04, 0.06, 0.65), Color(0.0, 0.94, 1.0, 0.4), 6, Color(0.0, 0.94, 1.0, 0.06)))
	
	button.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.0, 0.94, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))

	# Left sliding indicator bar
	var indicator := ColorRect.new()
	indicator.color = Color(0.0, 0.94, 1.0)
	indicator.custom_minimum_size = Vector2(4, 24)
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(indicator)
	
	indicator.anchor_top = 0.5
	indicator.anchor_bottom = 0.5
	indicator.offset_left = 12
	indicator.offset_top = -12
	indicator.offset_right = 16
	indicator.offset_bottom = 12
	indicator.modulate.a = 0.0
	indicator.scale.y = 0.0
	indicator.pivot_offset = Vector2(2, 12)
	
	button.pressed.connect(func():
		if Global:
			Global.play_sfx("click")
		callback.call()
	)s
	
	button.mouse_entered.connect(func(): _hover_button(button, true, indicator))
	button.mouse_exited.connect(func(): _hover_button(button, false, indicator))
	
	return button

func _make_level_button(level_num: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(92, 82)
	
	button.pressed.connect(func():
		if Global:
			Global.play_sfx("click")
			Global.load_level(level_num)
	)
	button.mouse_entered.connect(func(): _hover_level_button(button, true))
	button.mouse_exited.connect(func(): _hover_level_button(button, false))

	var container := VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(container)

	var num_label := Label.new()
	num_label.text = "%02d" % level_num
	num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_label.add_theme_font_override("font", FONT)
	num_label.add_theme_font_size_override("font_size", 24)
	num_label.add_theme_color_override("font_color", Color(0.88, 0.96, 1.0))
	container.add_child(num_label)

	var score := int(Global.get_best_score(level_num)) if Global else 0
	var score_label := Label.new()
	score_label.text = str(score) if score > 0 else "—"
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_override("font", FONT)
	score_label.add_theme_font_size_override("font_size", 10)
	score_label.add_theme_color_override("font_color", Color(0.0, 0.94, 1.0) if score > 0 else Color(0.42, 0.46, 0.54))
	container.add_child(score_label)

	button.add_theme_stylebox_override("normal", _button_style(Color(0.03, 0.04, 0.06, 0.65), Color(0.0, 0.94, 1.0, 0.22), 6, Color(0.0, 0.94, 1.0, 0.06)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.06, 0.12, 0.20, 0.85), Color(0.0, 0.94, 1.0, 0.95), 10, Color(0.0, 0.94, 1.0, 0.18)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.02, 0.06, 0.12, 0.95), Color(0.0, 0.94, 1.0, 1.0)))
	button.add_theme_stylebox_override("focus", _button_style(Color(0.03, 0.04, 0.06, 0.65), Color(0.0, 0.94, 1.0, 0.5)))
	
	return button

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

func _hover_button(button: Button, hovered: bool, indicator: ColorRect) -> void:
	button.pivot_offset = button.size * 0.5
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.04, 1.04) if hovered else Vector2.ONE, 0.14)
	
	var ind_tween := create_tween()
	ind_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ind_tween.tween_property(indicator, "modulate:a", 1.0 if hovered else 0.0, 0.14)
	ind_tween.parallel().tween_property(indicator, "scale:y", 1.0 if hovered else 0.0, 0.14)
	
	if hovered and Global:
		Global.play_sfx("hover")

func _hover_level_button(button: Button, hovered: bool) -> void:
	button.pivot_offset = button.size * 0.5
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.05, 1.05) if hovered else Vector2.ONE, 0.14)
	if hovered and Global:
		Global.play_sfx("hover")

func _show_panel(panel: Control, animated := true) -> void:
	# Hide all panels immediately or transition
	for child in [main_panel, level_panel, settings_panel]:
		if child != panel:
			child.visible = false
			child.modulate.a = 0.0
			child.position = Vector2.ZERO

	panel.visible = true
	if not animated:
		panel.modulate.a = 1.0
		panel.position = Vector2.ZERO
		return

	panel.modulate.a = 0.0
	panel.position.x = -24.0
	
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.24)
	tween.parallel().tween_property(panel, "position:x", 0.0, 0.24)
