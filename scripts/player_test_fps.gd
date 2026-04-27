extends CharacterBody3D

@onready var yaw_pivot: Node3D = $YawPivot
@onready var pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var camera: Camera3D = $YawPivot/PitchPivot/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var body_mesh: Skeleton3D = get_node_or_null("FirstPersonArms/Skeleton3D")
@onready var animation: AnimationPlayer = $AnimationPlayer
@onready var walking: AudioStreamPlayer3D = $walking
@onready var jump: AudioStreamPlayer3D = $jump
@onready var gun: Node3D = $YawPivot/PitchPivot/Camera3D/gun
@onready var gunshot: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var jab: AudioStreamPlayer2D = $jab
@onready var punch: AudioStreamPlayer2D = $punch

var can_move = true
var moving_anim = "walking"
var SPEED := 5.0

const JUMP_VELOCITY := 6
const GRAVITY_MAGNITUDE := 9.81
const MOUSE_SENS := 0.003

const BODY_ROTATE_SPEED := 8.0
const PITCH_ROTATE_SPEED := 14.0

const ACCEL := 25.0
const DECEL := 30.0
const PITCH_LIMIT := deg_to_rad(85.0)
const CAMERA_NEAR := 0.05
const CAMERA_HEIGHT_OFFSET := -0.3
const CAMERA_BOB_FREQUENCY := 9.0
const CAMERA_BOB_VERTICAL := 0.08
const CAMERA_BOB_HORIZONTAL := 0.025
const CAMERA_BOB_TILT := 0.015
const CAMERA_BOB_RETURN_SPEED := 10.0
const ANIMATION_BLEND_TIME := 0.18
const SWITCH_RAY_LENGTH := 100.0
const DIRECTION_EPSILON := 0.0001
const BULLET_RANGE := 120.0
const BULLET_RADIUS := 0.04
const BULLET_SPEED := 30.0
const BULLET_TRAIL_LENGTH := 0.45
const BULLET_LIGHT_RANGE := 3.5
const BULLET_LIGHT_ENERGY := 2.2
const BULLET_IMPACT_HOLD := 0.06

# Footstep sound settings
const WALK_PITCH := 1.0
const RUN_PITCH := 1.22
const WALK_VOLUME_DB := -4.0
const SILENT_VOLUME_DB := -80.0

# Punch/jab forward knockback strength
const PUNCH_KNOCKBACK := 2.5

var gravity_dir: Vector3 = Vector3.DOWN
var target_basis: Basis
var target_pitch := 0.0
var is_jumping = false
var was_on_floor := false
var current_animation := ""
var camera_bob_time := 0.0
var base_camera_position := Vector3.ZERO
var is_performing_action := false
var gun_mode := false
var action_locks_movement := false
var active_bullets: Array[Dictionary] = []

var combo_queued := false
var combo_action := ""

func _ready() -> void:
	gun.visible = gun_mode
	target_basis = global_transform.basis.orthonormalized()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	floor_snap_length = 0.5
	setup_first_person_view()
	was_on_floor = is_on_floor()
	play_animation("idle")

	walking.volume_db = SILENT_VOLUME_DB
	walking.pitch_scale = WALK_PITCH

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("run"):
		SPEED = 8 if SPEED == 5 else 5
		moving_anim = "running" if moving_anim == "walking" else "walking"

	if event.is_action_pressed("kick") and not gun_mode:
		if is_performing_action:
			combo_queued = true
			combo_action = "punch"
		else:
			punch.play()
			apply_punch_knockback()
			start_action_animation("punch", false)

	if event.is_action_pressed("jab") and not gun_mode:
		if is_performing_action:
			combo_queued = true
			combo_action = "jab"
		else:
			jab.play()
			apply_punch_knockback()
			start_action_animation("jab", false)

	if event.is_action_pressed("gun"):
		gun_mode = not gun_mode
		gun.visible = gun_mode
		current_animation = ""
		is_performing_action = false
		can_move = true
		combo_queued = false
		combo_action = ""

		if gun_mode:
			play_animation("gun")
		else:
			play_animation("idle")

	if event.is_action_pressed("shoot") and gun_mode:
		start_action_animation("shoot", false)
		fire_bullet()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return

	if event is InputEventMouseMotion:
		var up := -gravity_dir.normalized()

		target_basis = target_basis.rotated(up, -event.relative.x * MOUSE_SENS)
		target_basis = target_basis.orthonormalized()

		target_pitch -= event.relative.y * MOUSE_SENS
		target_pitch = clamp(target_pitch, -PITCH_LIMIT, PITCH_LIMIT)

func _physics_process(delta: float) -> void:
	up_direction = -gravity_dir.normalized()
	var started_on_floor := is_on_floor()

	if Input.is_action_just_pressed("switch"):
		var new_gravity_dir := get_switch_gravity_direction()
		if new_gravity_dir != Vector3.ZERO:
			change_gravity(new_gravity_dir)

	var body_alpha := 1.0 - exp(-BODY_ROTATE_SPEED * delta)
	transform.basis = transform.basis.slerp(target_basis, body_alpha).orthonormalized()

	var g := gravity_dir.normalized()

	if not is_on_floor():
		velocity += g * GRAVITY_MAGNITUDE * delta
	else:
		velocity -= g * velocity.dot(g)

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity -= g * JUMP_VELOCITY
		is_jumping = true
		jump.play()

	var input_dir := Input.get_vector("left", "right", "up", "down")
	var up := up_direction.normalized()

	var forward := -global_transform.basis.z
	forward = (forward - up * forward.dot(up)).normalized()

	var right := global_transform.basis.x
	right = (right - up * right.dot(up)).normalized()

	var move_dir := right * input_dir.x - forward * input_dir.y
	if move_dir.length_squared() > DIRECTION_EPSILON:
		move_dir = move_dir.normalized()
	else:
		move_dir = Vector3.ZERO

	var vertical_vel := up * velocity.dot(up)
	var horizontal_vel := velocity - vertical_vel

	if move_dir != Vector3.ZERO and can_move:
		var desired_horizontal := move_dir * SPEED
		horizontal_vel = horizontal_vel.move_toward(desired_horizontal, ACCEL * delta)
	else:
		horizontal_vel = horizontal_vel.move_toward(Vector3.ZERO, DECEL * delta)

	velocity = horizontal_vel + vertical_vel
	move_and_slide()

	var ended_on_floor := is_on_floor()
	update_animation_state(started_on_floor, ended_on_floor, move_dir)
	was_on_floor = ended_on_floor
	update_bullets(delta)

	var pitch_alpha := 1.0 - exp(-PITCH_ROTATE_SPEED * delta)
	pitch_pivot.rotation.x = lerp_angle(pitch_pivot.rotation.x, target_pitch, pitch_alpha)

	update_camera_bob(delta, horizontal_vel, ended_on_floor)
	update_footsteps(move_dir, ended_on_floor)

func apply_punch_knockback() -> void:
	var up := up_direction.normalized()
	var forward := -global_transform.basis.z
	forward = (forward - up * forward.dot(up)).normalized()
	velocity += forward * PUNCH_KNOCKBACK

func update_footsteps(move_dir: Vector3, grounded: bool) -> void:
	var is_moving := move_dir.length_squared() > DIRECTION_EPSILON and grounded and can_move

	if is_moving:
		if not walking.playing:
			walking.play()

		var target_pitch := RUN_PITCH if moving_anim == "running" else WALK_PITCH
		walking.pitch_scale = lerp(walking.pitch_scale, target_pitch, 0.15)
		walking.volume_db = lerp(walking.volume_db, WALK_VOLUME_DB, 0.15)
	else:
		walking.volume_db = lerp(walking.volume_db, SILENT_VOLUME_DB, 0.15)

		if walking.volume_db < -70.0 and walking.playing:
			walking.stop()

func get_switch_gravity_direction() -> Vector3:
	var ray_origin := camera.global_transform.origin
	var ray_end := ray_origin + (-camera.global_transform.basis.z * SWITCH_RAY_LENGTH)

	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [self.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector3.ZERO

	var normal: Vector3 = hit.normal
	if normal.length_squared() <= DIRECTION_EPSILON:
		return Vector3.ZERO

	return -normal.normalized()

func change_gravity(new_dir: Vector3) -> void:
	if new_dir.length_squared() <= DIRECTION_EPSILON:
		return

	new_dir = new_dir.normalized()
	if gravity_dir.normalized().dot(new_dir) > 0.999:
		return

	gravity_dir = new_dir
	is_jumping = false
	var new_up := -gravity_dir

	var forward := get_projected_forward_on_plane(new_up)
	target_basis = Basis.looking_at(forward, new_up).orthonormalized()

	velocity = velocity.slide(new_up)
	up_direction = new_up

func setup_first_person_view() -> void:
	var eye_height := 1.6
	var shape := collision_shape.shape

	if shape is CapsuleShape3D:
		eye_height = collision_shape.position.y + (shape.height * 0.5)

	eye_height += CAMERA_HEIGHT_OFFSET

	pitch_pivot.position = Vector3(0.0, eye_height, 0.0)
	camera.position = Vector3.ZERO
	base_camera_position = camera.position
	camera.near = CAMERA_NEAR

func update_camera_bob(delta: float, horizontal_vel: Vector3, grounded: bool) -> void:
	var move_speed := horizontal_vel.length()
	var move_ratio = clamp(move_speed / max(SPEED, 0.001), 0.0, 1.0)
	var is_walking = grounded and move_ratio > 0.1

	var target_offset := Vector3.ZERO
	var target_roll := 0.0

	if is_walking:
		camera_bob_time += delta * CAMERA_BOB_FREQUENCY * lerp(0.65, 1.2, move_ratio)
		target_offset.y = -abs(sin(camera_bob_time)) * CAMERA_BOB_VERTICAL * move_ratio
		target_offset.x = cos(camera_bob_time * 0.5) * CAMERA_BOB_HORIZONTAL * move_ratio
		target_roll = target_offset.x * CAMERA_BOB_TILT / CAMERA_BOB_HORIZONTAL

	camera.position = camera.position.lerp(base_camera_position + target_offset, delta * CAMERA_BOB_RETURN_SPEED)
	camera.rotation.z = lerp(camera.rotation.z, target_roll, delta * CAMERA_BOB_RETURN_SPEED)

func update_animation_state(started_on_floor: bool, ended_on_floor: bool, move_dir: Vector3) -> void:
	if is_performing_action:
		return

	if is_jumping and ended_on_floor and not started_on_floor:
		is_jumping = false

	if not ended_on_floor:
		is_jumping = true
		if gun_mode:
			play_animation("gun")
		else:
			play_animation("jump")
		return

	if gun_mode:
		play_animation("gun")
		return

	if move_dir.length_squared() > DIRECTION_EPSILON:
		play_animation(moving_anim)
		return

	play_animation("idle")

func play_animation(name: String) -> void:
	play_animation_with_blend(name, ANIMATION_BLEND_TIME)

func play_animation_with_blend(name: String, blend: float = ANIMATION_BLEND_TIME, force: bool = false) -> void:
	if not force and current_animation == name and animation.is_playing():
		return

	if animation.has_animation(name):
		animation.play(name, blend)
		current_animation = name
	elif name == "idle":
		animation.stop()
		current_animation = ""

func start_action_animation(name: String, lock_movement: bool = true) -> void:
	if is_performing_action or not animation.has_animation(name):
		return

	is_performing_action = true
	action_locks_movement = lock_movement
	if lock_movement:
		can_move = false
	play_animation_with_blend(name, 0.1, true)
	finish_action_animation()

func finish_action_animation() -> void:
	await animation.animation_finished
	current_animation = ""
	if action_locks_movement:
		can_move = true
	action_locks_movement = false
	is_performing_action = false

	if combo_queued and not gun_mode:
		combo_queued = false
		var next := combo_action
		combo_action = ""
		if next == "punch":
			punch.play()
		elif next == "jab":
			jab.play()
		apply_punch_knockback()
		start_action_animation(next, false)
	else:
		combo_queued = false
		combo_action = ""

func fire_bullet() -> void:
	gunshot.play()
	var start := gun.global_transform.origin
	var direction := -camera.global_transform.basis.z.normalized()
	spawn_bullet_projectile(start, direction)

func spawn_bullet_projectile(start: Vector3, direction: Vector3) -> void:
	if direction.length_squared() <= DIRECTION_EPSILON:
		return

	var projectile := Node3D.new()
	var bullet_mesh_instance := MeshInstance3D.new()
	var trail_mesh_instance := MeshInstance3D.new()
	var bullet_light := OmniLight3D.new()
	var bullet_mesh := SphereMesh.new()
	var trail_mesh := CylinderMesh.new()
	var material := StandardMaterial3D.new()

	bullet_mesh.radius = BULLET_RADIUS
	bullet_mesh.height = BULLET_RADIUS * 2.0

	trail_mesh.top_radius = BULLET_RADIUS * 0.55
	trail_mesh.bottom_radius = BULLET_RADIUS * 1.15
	trail_mesh.height = BULLET_TRAIL_LENGTH
	trail_mesh.radial_segments = 8
	trail_mesh.rings = 1

	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.2, 1.0, 0.35, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.2, 1.0, 0.35, 1.0)
	material.emission_energy_multiplier = 4.5

	bullet_mesh_instance.mesh = bullet_mesh
	bullet_mesh_instance.material_override = material
	bullet_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	trail_mesh_instance.mesh = trail_mesh
	trail_mesh_instance.material_override = material
	trail_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail_mesh_instance.position = Vector3(0.0, 0.0, BULLET_TRAIL_LENGTH * 0.5)
	trail_mesh_instance.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))

	bullet_light.light_color = Color(0.2, 1.0, 0.35, 1.0)
	bullet_light.light_energy = BULLET_LIGHT_ENERGY
	bullet_light.omni_range = BULLET_LIGHT_RANGE
	bullet_light.shadow_enabled = false
	bullet_light.light_specular = 0.2

	projectile.add_child(trail_mesh_instance)
	projectile.add_child(bullet_mesh_instance)
	projectile.add_child(bullet_light)
	get_tree().current_scene.add_child(projectile)

	projectile.global_transform = Transform3D.IDENTITY
	projectile.global_position = start
	projectile.look_at(start - direction, Vector3.UP)

	active_bullets.append({
		"node": projectile,
		"direction": direction,
		"traveled": 0.0,
		"impact_timer": -1.0
	})

func update_bullets(delta: float) -> void:
	for i in range(active_bullets.size() - 1, -1, -1):
		var bullet := active_bullets[i]
		var projectile: Node3D = bullet["node"]

		if not is_instance_valid(projectile):
			active_bullets.remove_at(i)
			continue

		var impact_timer: float = bullet["impact_timer"]
		if impact_timer >= 0.0:
			impact_timer -= delta
			if impact_timer <= 0.0:
				projectile.queue_free()
				active_bullets.remove_at(i)
			else:
				bullet["impact_timer"] = impact_timer
				active_bullets[i] = bullet
			continue

		var direction: Vector3 = bullet["direction"]
		var step := BULLET_SPEED * delta
		var start := projectile.global_transform.origin
		var end := start + direction * step

		var query := PhysicsRayQueryParameters3D.create(start, end)
		query.exclude = [self.get_rid()]
		query.collide_with_areas = false
		query.collide_with_bodies = true

		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			projectile.global_position = hit.position
			bullet["impact_timer"] = BULLET_IMPACT_HOLD
			active_bullets[i] = bullet
			continue

		projectile.global_position = end
		bullet["traveled"] = bullet["traveled"] + step
		if bullet["traveled"] >= BULLET_RANGE:
			projectile.queue_free()
			active_bullets.remove_at(i)
		else:
			active_bullets[i] = bullet

func get_projected_forward_on_plane(new_up: Vector3) -> Vector3:
	var candidates := [
		-camera.global_transform.basis.z,
		-global_transform.basis.z,
		global_transform.basis.x
	]

	for candidate in candidates:
		var projected = candidate - new_up * candidate.dot(new_up)

		if projected.length_squared() > DIRECTION_EPSILON:
			return projected.normalized()

	return get_orthogonal_vector(new_up)

func get_orthogonal_vector(v: Vector3) -> Vector3:
	var axis := Vector3.UP

	if abs(v.dot(axis)) > 0.99:
		axis = Vector3.RIGHT

	var orthogonal := axis - v * axis.dot(v)
	return orthogonal.normalized()
