extends CharacterBody3D

@onready var yaw_pivot: Node3D = $YawPivot
@onready var pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var camera: Camera3D = $YawPivot/PitchPivot/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var body_mesh: Skeleton3D = $mixamo_base/Armature/Skeleton3D
@onready var animation: AnimationPlayer = $mixamo_base/AnimationPlayer

var can_move=true
var moving_anim='walking'
var SPEED := 5.0
const JUMP_VELOCITY := 4.5
const GRAVITY_MAGNITUDE := 9.81
const MOUSE_SENS := 0.003

const BODY_ROTATE_SPEED := 8.0
const PITCH_ROTATE_SPEED := 14.0

const ACCEL := 25.0
const DECEL := 30.0
const PITCH_LIMIT := deg_to_rad(85.0)
const CAMERA_NEAR := 0.05
const CAMERA_HEIGHT_OFFSET := -0.3
const ANIMATION_BLEND_TIME := 0.18
const SWITCH_RAY_LENGTH := 100.0
const DIRECTION_EPSILON := 0.0001

var gravity_dir: Vector3 = Vector3.DOWN
var target_basis: Basis
var target_pitch := 0.0
var is_jumping = false
var was_on_floor := false
var current_animation := ""

func _ready() -> void:
	target_basis = global_transform.basis.orthonormalized()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	floor_snap_length = 0.5
	setup_first_person_view()
	was_on_floor = is_on_floor()
	play_animation("idle")
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("run"):
		SPEED=8 if SPEED==5 else 5
		moving_anim='running' if moving_anim=='walking' else 'walking'
	if event.is_action_pressed("kick"):
		can_move=false
		play_animation_with_blend("kick", 0.1, true)
		await animation.animation_finished
		current_animation = ""
		can_move=true

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

	if move_dir != Vector3.ZERO:
		var desired_horizontal := move_dir * SPEED
		horizontal_vel = horizontal_vel.move_toward(desired_horizontal, ACCEL * delta)
	else:
		horizontal_vel = horizontal_vel.move_toward(Vector3.ZERO, DECEL * delta)

	velocity = horizontal_vel + vertical_vel
	move_and_slide()

	var ended_on_floor := is_on_floor()
	update_animation_state(started_on_floor, ended_on_floor, move_dir)
	was_on_floor = ended_on_floor

	var pitch_alpha := 1.0 - exp(-PITCH_ROTATE_SPEED * delta)
	pitch_pivot.rotation.x = lerp_angle(pitch_pivot.rotation.x, target_pitch, pitch_alpha)

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
	is_jumping=false
	var new_up := -gravity_dir

	var forward := get_projected_forward_on_plane(new_up)
	target_basis = Basis.looking_at(forward, new_up).orthonormalized()

	# Keep momentum tangent to the new floor.
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
	camera.near = CAMERA_NEAR

func update_animation_state(started_on_floor: bool, ended_on_floor: bool, move_dir: Vector3) -> void:
	if is_jumping and ended_on_floor and not started_on_floor:
		is_jumping = false

	if not ended_on_floor:
		is_jumping = true
		play_animation("jump")
		return

	if move_dir.length_squared() > DIRECTION_EPSILON:
		play_animation(moving_anim)
		return

	play_animation("idle")

func play_animation(name: String) -> void:
	play_animation_with_blend(name, ANIMATION_BLEND_TIME)

func play_animation_with_blend(name: String, blend: float = ANIMATION_BLEND_TIME, force: bool = false) -> void:
	if not force and current_animation == name:
		return

	if animation.has_animation(name):
		animation.play(name, blend)
		current_animation = name

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
