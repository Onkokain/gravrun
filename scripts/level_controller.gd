extends Node3D

@export_range(1, 10) var level_number := 1

const PLAYER_SCENE := preload("res://scripts/player_test_fps.tscn")
const HUD_SCRIPT := preload("res://scripts/game_hud.gd")
const COMPLETE_SCRIPT := preload("res://scripts/level_complete_screen.gd")
const MOVING_PLATFORM_SCRIPT := preload("res://scripts/moving_platform.gd")
const ROTATING_HAZARD_SCRIPT := preload("res://scripts/rotating_hazard.gd")

var player: CharacterBody3D
var spawn_transform := Transform3D.IDENTITY
var completed := false

func _ready() -> void:
	get_tree().paused = false
	Global.start_level(level_number)
	_build_world()
	add_child(HUD_SCRIPT.new())

func _build_world() -> void:
	_add_environment()
	spawn_transform = Transform3D(Basis.IDENTITY, Vector3(0, 2.2, 0))
	player = PLAYER_SCENE.instantiate()
	player.name = "Player"
	add_child(player)
	player.global_transform = spawn_transform

	var defs: Array = _level_defs()[level_number - 1]
	for item in defs:
		match String(item["type"]):
			"platform":
				_add_platform(item)
			"moving":
				_add_moving_platform(item)
			"hazard":
				_add_hazard(item)
			"rotator":
				_add_rotator(item)
			"finish":
				_add_finish(item)
			"light":
				_add_light(item)

	_add_death_floor()

func _add_environment() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = load("res://shaders/new_environment.tres")
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.72, 0.85, 1.0)
	sun.light_energy = 1.4
	sun.rotation_degrees = Vector3(-52, 32, 0)
	add_child(sun)

	var ambient := OmniLight3D.new()
	ambient.position = Vector3(0, 10, 0)
	ambient.light_color = Color(0.24, 0.63, 1.0)
	ambient.light_energy = 2.0
	ambient.omni_range = 80
	add_child(ambient)

func _add_platform(item: Dictionary) -> void:
	var body := StaticBody3D.new()
	body.name = "Platform"
	body.position = item["pos"]
	add_child(body)
	body.add_child(_mesh_box(item["size"], _mat(item.get("color", Color(0.13, 0.17, 0.24)))))
	body.add_child(_collision_box(item["size"]))

func _add_moving_platform(item: Dictionary) -> void:
	var body := AnimatableBody3D.new()
	body.set_script(MOVING_PLATFORM_SCRIPT)
	body.name = "MovingPlatform"
	body.position = item["pos"]
	body.travel = item["travel"]
	body.duration = float(item.get("duration", 2.0))
	body.phase = float(item.get("phase", 0.0))
	add_child(body)
	body.add_child(_mesh_box(item["size"], _mat(Color(0.08, 0.28, 0.36))))
	body.add_child(_collision_box(item["size"]))

func _add_hazard(item: Dictionary) -> void:
	var area := Area3D.new()
	area.name = "Hazard"
	area.position = item["pos"]
	add_child(area)
	area.body_entered.connect(_on_hazard_entered)
	area.add_child(_mesh_box(item["size"], _mat(Color(0.9, 0.08, 0.1, 0.82), true)))
	area.add_child(_collision_box(item["size"]))

func _add_rotator(item: Dictionary) -> void:
	var pivot := Node3D.new()
	pivot.set_script(ROTATING_HAZARD_SCRIPT)
	pivot.name = "RotatingHazard"
	pivot.position = item["pos"]
	pivot.rotation_axis = item.get("axis", Vector3.UP)
	pivot.rotation_speed = float(item.get("speed", 1.7))
	add_child(pivot)

	var arm := Area3D.new()
	arm.position = item.get("offset", Vector3.ZERO)
	pivot.add_child(arm)
	arm.body_entered.connect(_on_hazard_entered)
	arm.add_child(_mesh_box(item["size"], _mat(Color(1.0, 0.18, 0.12, 0.86), true)))
	arm.add_child(_collision_box(item["size"]))

func _add_finish(item: Dictionary) -> void:
	var area := Area3D.new()
	area.name = "Finish"
	area.position = item["pos"]
	add_child(area)
	area.body_entered.connect(_on_finish_entered)
	area.add_child(_mesh_box(item["size"], _mat(Color(0.1, 0.95, 0.68, 0.62), true)))
	area.add_child(_collision_box(item["size"]))

func _add_light(item: Dictionary) -> void:
	var light := OmniLight3D.new()
	light.position = item["pos"]
	light.light_color = item.get("color", Color(0.2, 0.65, 1.0))
	light.light_energy = float(item.get("energy", 2.2))
	light.omni_range = float(item.get("range", 18.0))
	add_child(light)

func _add_death_floor() -> void:
	var area := Area3D.new()
	area.name = "DeathVolume"
	area.position = Vector3(0, -24, 75)
	add_child(area)
	area.body_entered.connect(_on_hazard_entered)
	area.add_child(_collision_box(Vector3(260, 8, 260)))

func _mesh_box(size: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	return mesh_instance

func _collision_box(size: Vector3) -> CollisionShape3D:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	return collision

func _mat(color: Color, emission := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.68
	if emission:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.2
	return material

func _on_hazard_entered(body: Node3D) -> void:
	if body != player or completed:
		return
	Global.play_sfx("death")
	Global.record_death()
	_respawn_player()

func _respawn_player() -> void:
	player.velocity = Vector3.ZERO
	if player.has_method("reset_gravity_state"):
		player.reset_gravity_state()
	player.global_transform = spawn_transform
	var hud := get_tree().get_first_node_in_group("stamina_hud")
	if hud and hud.has_method("refill"):
		hud.refill()
	_show_retry_flash()

func _show_retry_flash() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 45
	add_child(layer)

	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.04, 0.005, 0.008, 1.0)
	layer.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)

	var label := Label.new()
	label.text = "RECONFIGURING PROTOCOL"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", load("res://assets/public/fonts/ArkitechLight-ovWKz.otf"))
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.22))
	box.add_child(label)
	
	var sublabel := Label.new()
	sublabel.text = "ATTEMPT LIMITS: INFINITE | ATTEMPT: %d" % Global.run_deaths
	sublabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sublabel.add_theme_font_override("font", load("res://assets/public/fonts/ArkitechLight-ovWKz.otf"))
	sublabel.add_theme_font_size_override("font_size", 12)
	sublabel.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8, 0.6))
	box.add_child(sublabel)

	box.pivot_offset = Vector2(250, 25)
	box.scale = Vector2(0.92, 0.92)

	var tween := layer.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(overlay, "color:a", 0.0, 0.58)
	tween.parallel().tween_property(box, "scale", Vector2(1.05, 1.05), 0.58)
	tween.parallel().tween_property(box, "modulate:a", 0.0, 0.52)
	tween.finished.connect(layer.queue_free)

func _on_finish_entered(body: Node3D) -> void:
	if body != player or completed:
		return
	completed = true
	var stats := Global.complete_level()
	var screen := COMPLETE_SCRIPT.new()
	screen.setup(stats)
	add_child(screen)

func _level_defs() -> Array:
	return [
		# Level 1: Introduction to Gravity (Ceiling switch introduction)
		[
			{"type":"platform","pos":Vector3(0,0,0),"size":Vector3(8,1,10)},
			{"type":"platform","pos":Vector3(0,8,16),"size":Vector3(8,1,16),"color":Color(0.15,0.22,0.32)},
			{"type":"platform","pos":Vector3(0,0,32),"size":Vector3(8,1,10)},
			{"type":"finish","pos":Vector3(0,1.2,38),"size":Vector3(5,3,1)}
		],
		# Level 2: Wall Runs (Traversing left/right walls)
		[
			{"type":"platform","pos":Vector3(0,0,0),"size":Vector3(8,1,10)},
			{"type":"platform","pos":Vector3(6,4,18),"size":Vector3(1,8,22),"color":Color(0.18,0.25,0.35)},
			{"type":"platform","pos":Vector3(0,0,34),"size":Vector3(8,1,10)},
			{"type":"finish","pos":Vector3(0,1.2,40),"size":Vector3(5,3,1)}
		],
		# Level 3: Moving Platforms & Timing (Side wall & moving platform combo)
		[
			{"type":"platform","pos":Vector3(0,0,0),"size":Vector3(8,1,10)},
			{"type":"moving","pos":Vector3(0,0,13),"size":Vector3(5,0.8,5),"travel":Vector3(6,0,0),"duration":2.2},
			{"type":"platform","pos":Vector3(6,0,24),"size":Vector3(6,1,6)},
			{"type":"platform","pos":Vector3(-3,4,33),"size":Vector3(1,8,12),"color":Color(0.18,0.25,0.35)},
			{"type":"platform","pos":Vector3(3,0,42),"size":Vector3(6,1,6)},
			{"type":"finish","pos":Vector3(3,1.2,46),"size":Vector3(4,3,1)}
		],
		# Level 4: The Ceiling Maze (Alternating ceilings and floor hazards)
		[
			{"type":"platform","pos":Vector3(0,0,0),"size":Vector3(8,1,10)},
			{"type":"platform","pos":Vector3(0,10,16),"size":Vector3(8,1,14),"color":Color(0.15,0.22,0.32)},
			{"type":"platform","pos":Vector3(0,5,32),"size":Vector3(8,1,14),"color":Color(0.2,0.28,0.38)},
			{"type":"hazard","pos":Vector3(0,-1,32),"size":Vector3(12,1,16)},
			{"type":"platform","pos":Vector3(0,0,46),"size":Vector3(8,1,10)},
			{"type":"finish","pos":Vector3(0,1.2,52),"size":Vector3(5,3,1)}
		],
		# Level 5: The Helix (Vertical climbs and rotating hazards)
		[
			{"type":"platform","pos":Vector3(0,0,0),"size":Vector3(8,1,10)},
			{"type":"platform","pos":Vector3(0,8,18),"size":Vector3(4,16,4),"color":Color(0.22,0.28,0.36)},
			{"type":"rotator","pos":Vector3(0,5,18),"size":Vector3(12,0.6,0.8),"speed":1.6},
			{"type":"rotator","pos":Vector3(0,11,18),"size":Vector3(12,0.6,0.8),"speed":-1.8},
			{"type":"platform","pos":Vector3(0,16,28),"size":Vector3(8,1,8)},
			{"type":"finish","pos":Vector3(0,17.2,33),"size":Vector3(4,3,1)}
		],
		# Level 6: Gravity Puzzle (Wall-to-ceiling navigations to bypass barrier walls)
		[
			{"type":"platform","pos":Vector3(0,0,0),"size":Vector3(8,1,10)},
			{"type":"hazard","pos":Vector3(0,1.5,15),"size":Vector3(8,3,2)},
			{"type":"platform","pos":Vector3(0,7,15),"size":Vector3(8,1,8)},
			{"type":"hazard","pos":Vector3(-3.5,4,27),"size":Vector3(3,8,2)},
			{"type":"platform","pos":Vector3(3.5,4,27),"size":Vector3(1,8,8)},
			{"type":"hazard","pos":Vector3(3.5,4,39),"size":Vector3(3,8,2)},
			{"type":"platform","pos":Vector3(-3.5,4,39),"size":Vector3(1,8,8)},
			{"type":"platform","pos":Vector3(0,0,51),"size":Vector3(8,1,10)},
			{"type":"finish","pos":Vector3(0,1.2,57),"size":Vector3(5,3,1)}
		],
		# Level 7: Ceiling Runner (Upside down movement dodging moving hazard blocks)
		[
			{"type":"platform","pos":Vector3(0,0,0),"size":Vector3(8,1,10)},
			{"type":"platform","pos":Vector3(0,12,24),"size":Vector3(8,1,34),"color":Color(0.12,0.22,0.32)},
			{"type":"moving","pos":Vector3(0,3,18),"size":Vector3(12,2,4),"travel":Vector3(0,6,0),"duration":2.2},
			{"type":"moving","pos":Vector3(0,9,30),"size":Vector3(12,2,4),"travel":Vector3(0,-6,0),"duration":2.2},
			{"type":"platform","pos":Vector3(0,0,46),"size":Vector3(8,1,10)},
			{"type":"finish","pos":Vector3(0,1.2,52),"size":Vector3(5,3,1)}
		],
		# Level 8: Precision Tunnel (Alternating safe platforms on floors, ceilings, and walls)
		[
			{"type":"platform","pos":Vector3(0,0,0),"size":Vector3(8,1,10)},
			{"type":"platform","pos":Vector3(0,0,14),"size":Vector3(6,1,8)},
			{"type":"platform","pos":Vector3(0,8,26),"size":Vector3(6,1,8),"color":Color(0.12,0.22,0.32)},
			{"type":"hazard","pos":Vector3(0,0,26),"size":Vector3(8,1,10)},
			{"type":"platform","pos":Vector3(-4,4,38),"size":Vector3(1,6,8)},
			{"type":"hazard","pos":Vector3(0,0,38),"size":Vector3(8,1,10)},
			{"type":"hazard","pos":Vector3(0,8,38),"size":Vector3(8,1,10)},
			{"type":"platform","pos":Vector3(4,4,50),"size":Vector3(1,6,8)},
			{"type":"hazard","pos":Vector3(0,0,50),"size":Vector3(8,1,10)},
			{"type":"hazard","pos":Vector3(0,8,50),"size":Vector3(8,1,10)},
			{"type":"platform","pos":Vector3(0,0,62),"size":Vector3(8,1,10)},
			{"type":"finish","pos":Vector3(0,1.2,68),"size":Vector3(5,3,1)}
		],
		# Level 9: Hazard Vortex (Chain of moving platforms paired with rotating sweeps)
		[
			{"type":"platform","pos":Vector3(0,0,0),"size":Vector3(8,1,10)},
			{"type":"moving","pos":Vector3(-4,0,14),"size":Vector3(4,0.8,4),"travel":Vector3(8,0,0),"duration":2.0},
			{"type":"rotator","pos":Vector3(0,2,22),"size":Vector3(14,0.6,0.8),"speed":2.0},
			{"type":"moving","pos":Vector3(0,0,30),"size":Vector3(4,0.8,4),"travel":Vector3(0,8,0),"duration":2.4},
			{"type":"rotator","pos":Vector3(0,7,38),"size":Vector3(14,0.6,0.8),"axis":Vector3.FORWARD,"speed":2.2},
			{"type":"moving","pos":Vector3(0,8,46),"size":Vector3(4,0.8,4),"travel":Vector3(0,0,8),"duration":1.8},
			{"type":"platform","pos":Vector3(0,8,60),"size":Vector3(8,1,10)},
			{"type":"finish","pos":Vector3(0,9.2,65),"size":Vector3(5,3,1)}
		],
		# Level 10: The Grand Protocol (Final Master Challenge)
		[
			# Phase 1: Wall climb shaft
			{"type":"platform","pos":Vector3(0,0,0),"size":Vector3(8,1,10)},
			{"type":"platform","pos":Vector3(-5,6,12),"size":Vector3(1,12,8)},
			{"type":"platform","pos":Vector3(5,14,22),"size":Vector3(1,12,8)},
			{"type":"platform","pos":Vector3(-5,22,32),"size":Vector3(1,12,8)},
			# Phase 2: Ceiling run with rotators
			{"type":"platform","pos":Vector3(0,28,48),"size":Vector3(8,1,24),"color":Color(0.12,0.22,0.32)},
			{"type":"rotator","pos":Vector3(0,24,44),"size":Vector3(16,0.8,0.8),"speed":2.8},
			{"type":"rotator","pos":Vector3(0,24,56),"size":Vector3(16,0.8,0.8),"speed":-2.8},
			# Phase 3: Drop into gravity maze
			{"type":"platform","pos":Vector3(0,10,74),"size":Vector3(10,1,16)},
			{"type":"hazard","pos":Vector3(0,12,74),"size":Vector3(6,3,16)},
			{"type":"platform","pos":Vector3(-5,14,74),"size":Vector3(1,8,16)},
			{"type":"platform","pos":Vector3(5,14,74),"size":Vector3(1,8,16)},
			# Phase 4: Precision sideways moves
			{"type":"platform","pos":Vector3(-5,18,94),"size":Vector3(1,4,4)},
			{"type":"moving","pos":Vector3(0,18,106),"size":Vector3(4,4,0.8),"travel":Vector3(0,-6,0),"duration":2.0},
			{"type":"platform","pos":Vector3(5,12,118),"size":Vector3(1,4,4)},
			# Phase 5: Final run and dash sweep
			{"type":"platform","pos":Vector3(0,0,136),"size":Vector3(8,1,22)},
			{"type":"rotator","pos":Vector3(0,3,142),"size":Vector3(22,0.8,0.8),"axis":Vector3.FORWARD,"speed":3.5},
			{"type":"platform","pos":Vector3(0,0,154),"size":Vector3(8,1,10)},
			{"type":"finish","pos":Vector3(0,1.2,159),"size":Vector3(4,3,1)}
		],
	]
