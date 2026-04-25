extends Node3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var opened=false


func _on_opener_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and !opened:
		opened=true
		animation_player.play("open")
