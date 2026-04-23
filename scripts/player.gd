extends CharacterBody3D

@onready var yaw_pivot: Node3D = $YawPivot
@onready var pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var camera: Camera3D = $YawPivot/PitchPivot/Camera3D

const SPEED := 6.0
const JUMP_VELOCITY := 4.5
const GRAVITY_MAGNITUDE := 9.81
const MOUSE_SENS := 0.003

const BODY_ROTATE_SPEED := 8.0
const PITCH_ROTATE_SPEED := 14.0

const ACCEL := 25.0
const DECEL := 30.0
const PITCH_LIMIT := deg_to_rad(120.0)

var gravity_dir: Vector3 = Vector3.DOWN
var target_basis: Basis
var target_pitch := 0.0

func _ready() -> void:
	target_basis = global_transform.basis.orthonormalized()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	floor_snap_length = 0.5

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

	if Input.is_action_just_pressed("switch"):
		change_gravity(get_closest_axis(-camera.global_transform.basis.z))

	var body_alpha := 1.0 - exp(-BODY_ROTATE_SPEED * delta)
	transform.basis = transform.basis.slerp(target_basis, body_alpha)

	var g := gravity_dir.normalized()

	if not is_on_floor():
		velocity += g * GRAVITY_MAGNITUDE * delta
	else:
		velocity -= g * velocity.dot(g)

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity -= g * JUMP_VELOCITY

	var input_dir := Input.get_vector("left", "right", "up", "down")

	var up := up_direction.normalized()

	var forward := -global_transform.basis.z
	forward = forward - up * forward.dot(up)
	if forward.length_squared() > 0.0001:
		forward = forward.normalized()
	else:
		forward = Vector3.ZERO

	var right := global_transform.basis.x
	right = right - up * right.dot(up)
	if right.length_squared() > 0.0001:
		right = right.normalized()
	else:
		right = Vector3.ZERO

	var move_dir := (right * input_dir.x - forward * input_dir.y).normalized()

	var vertical_vel := up * velocity.dot(up)
	var horizontal_vel := velocity - vertical_vel

	if move_dir != Vector3.ZERO:
		var desired_horizontal := move_dir * SPEED
		horizontal_vel = horizontal_vel.move_toward(desired_horizontal, ACCEL * delta)
	else:
		horizontal_vel = horizontal_vel.move_toward(Vector3.ZERO, DECEL * delta)

	velocity = horizontal_vel + vertical_vel
	move_and_slide()

	var pitch_alpha := 1.0 - exp(-PITCH_ROTATE_SPEED * delta)
	pitch_pivot.rotation.x = lerp_angle(pitch_pivot.rotation.x, target_pitch, pitch_alpha)

func change_gravity(new_dir: Vector3) -> void:
	new_dir = new_dir.normalized()
	if gravity_dir == new_dir:
		return

	gravity_dir = new_dir

	var new_up := -gravity_dir

	# Keep the current facing direction as much as possible on the new surface.
	var forward := -global_transform.basis.z
	forward = forward - new_up * forward.dot(new_up)

	if forward.length_squared() < 0.0001:
		forward = global_transform.basis.x
		forward = forward - new_up * forward.dot(new_up)

	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD

	forward = forward.normalized()
	target_basis = Basis.looking_at(forward, new_up).orthonormalized()

	# Keep momentum along the new surface instead of killing all velocity.
	velocity = velocity.slide(new_up)

	up_direction = new_up
	apply_floor_snap()

func get_closest_axis(v: Vector3) -> Vector3:
	var a := v.abs()

	if a.x > a.y and a.x > a.z:
		return Vector3(sign(v.x), 0, 0)
	elif a.y > a.x and a.y > a.z:
		return Vector3(0, sign(v.y), 0)
	else:
		return Vector3(0, 0, sign(v.z))
