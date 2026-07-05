extends AnimatableBody3D

@export var travel := Vector3.ZERO
@export var duration := 2.0
@export var phase := 0.0

var _origin := Vector3.ZERO

func _ready() -> void:
	_origin = global_position

func _physics_process(_delta: float) -> void:
	if duration <= 0.0:
		return

	var t := Time.get_ticks_msec() / 1000.0
	var wave := (sin((t + phase) / duration * TAU) + 1.0) * 0.5
	global_position = _origin + travel * wave
