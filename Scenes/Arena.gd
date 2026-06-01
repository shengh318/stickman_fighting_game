extends Node2D

@onready var pause_menu: CanvasLayer = $PauseMenu

var platform_data := []

func _ready() -> void:
	pause_menu.hide()
	$PauseMenu/ResumeButton.pressed.connect(_on_resume_pressed)
	$PauseMenu/QuitButton.pressed.connect(_on_quit_pressed)

	for child in get_children():
		if child.name.begins_with("Platform"):
			var shape = child.get_node("CollisionShape2D").shape
			var r = Rect2(
				child.position.x - shape.size.x / 2,
				child.position.y - shape.size.y / 2,
				shape.size.x,
				shape.size.y
			)
			platform_data.append({"rect": r, "color": Color(0.35, 0.35, 0.35)})
		elif child.name == "KillFloor":
			var shape = child.get_node("CollisionShape2D").shape
			var r = Rect2(
				child.position.x - shape.size.x / 2,
				child.position.y - shape.size.y / 2,
				shape.size.x,
				shape.size.y
			)
			platform_data.append({"rect": r, "color": Color(0.6, 0.1, 0.1, 0.5)})

	queue_redraw()

func _draw() -> void:
	for p in platform_data:
		draw_rect(p.rect, p.color)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		if get_tree().paused:
			pause_menu.hide()
			get_tree().paused = false
		else:
			pause_menu.show()
			get_tree().paused = true

func _on_resume_pressed() -> void:
	pause_menu.hide()
	get_tree().paused = false

func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
