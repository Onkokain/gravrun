extends Node3D

@export var rotation_axis := Vector3.UP
@export var rotation_speed := 1.6

func _physics_process(delta: float) -> void:
	rotate_object_local(rotation_axis.normalized(), rotation_speed * delta)
