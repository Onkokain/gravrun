extends Node3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var audio: AudioStreamPlayer2D = $AudioStreamPlayer2D

var opened=false
var interactable=true


func _on_opener_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and !opened and interactable:
		interactable=false
		opened=true
		audio.play()
		animation_player.play("open")
		await animation_player.animation_finished
		interactable=true
		


func _on_opener_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D and interactable and opened:
		interactable=false
		opened=false
		audio.play()
		animation_player.play("close")
		await animation_player.animation_finished
		interactable=true
		
