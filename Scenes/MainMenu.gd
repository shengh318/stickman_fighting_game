extends Control

@onready var host_button: Button = $HostButton
@onready var join_button: Button = $JoinButton
@onready var quit_button: Button = $QuitButton

func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_host_pressed() -> void:
	var arena = load("res://Scenes/Arena.tscn")
	if arena:
		get_tree().change_scene_to_packed(arena)
	else:
		print("ERROR: Could not load Arena.tscn")

func _on_join_pressed() -> void:
	print("Join pressed — placeholder")

func _on_quit_pressed() -> void:
	get_tree().quit()
