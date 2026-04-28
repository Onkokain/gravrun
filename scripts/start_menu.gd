extends Node2D

@onready var main_menu: Node2D = $"Main Menu"

@onready var settings: Node2D = $Settings
@onready var main_settings: Node2D = $"Settings/Panel/Main Settings"
@onready var audio: Node2D = $Settings/Panel/Audio
@onready var visuals: Node2D = $Settings/Panel/Visuals

@onready var level_selector: Node2D = $"Level Selector"



func _ready() -> void:
	main_menu.visible=true
	settings.visible=false
	level_selector.visible=false


func _on_play_button_up() -> void:
	main_menu.visible=false
	level_selector.visible=true
	


func _on_settings_button_up() -> void:
	main_menu.visible=false
	settings.visible=true

func _on_quit_button_up() -> void:
	get_tree().quit()


func _on_close_settings_button_up() -> void:
	main_menu.visible=true
	settings.visible=false


func _on_close_level_selector_button_up() -> void:
	main_menu.visible=true
	level_selector.visible=false
