extends Node2D

var stickman: CharacterBody2D

var respawn_node: Node2D = null
var respawn_life: float = 0.0
var is_respawning: bool = false

const FALL_DEATH_Y = 1120
const RESPAWN_DURATION = 3.0
const PLATFORM_FALL_DURATION = 0.8
const PLATFORM_X = 960
const PLATFORM_Y_TARGET = 320.0
const PLATFORM_Y_START = -250.0
const PLATFORM_W = 280
const PLATFORM_H = 24
const PLATFORM_COLOR = Color(0.5, 0.7, 0.9, 0.35)
const FLASH_DURATION = 0.8

var platform_rects: Array[Rect2] = []

@onready var pause_menu: CanvasLayer = $PauseMenu

func _ready() -> void:
	stickman = $Stickman
	pause_menu.hide()
	$PauseMenu/ResumeButton.pressed.connect(_on_resume_pressed)
	$PauseMenu/QuitButton.pressed.connect(_on_quit_pressed)

	for child in get_children():
		if child.name.begins_with("Platform"):
			var shape = child.get_node("CollisionShape2D").shape as RectangleShape2D
			if shape:
				platform_rects.append(Rect2(
					child.position.x - shape.size.x / 2,
					child.position.y - shape.size.y / 2,
					shape.size.x,
					shape.size.y
				))
	queue_redraw()

func _draw() -> void:
	for r in platform_rects:
		draw_rect(r, Color(0.35, 0.35, 0.35))

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		if get_tree().paused:
			pause_menu.hide()
			get_tree().paused = false
		else:
			pause_menu.show()
			get_tree().paused = true

	if is_respawning:
		update_respawn_platform(delta)
	elif stickman and stickman.global_position.y > FALL_DEATH_Y:
		start_respawn()

func start_respawn() -> void:
	is_respawning = true
	stickman.hide()
	stickman.set_physics_process(false)
	stickman.set_process(true)

	create_respawn_platform()

func create_respawn_platform() -> void:
	respawn_node = Node2D.new()
	add_child(respawn_node)
	move_child(respawn_node, stickman.get_index())
	respawn_node.position = Vector2(PLATFORM_X, PLATFORM_Y_START)

	var rect = ColorRect.new()
	rect.name = "Visual"
	rect.color = PLATFORM_COLOR
	rect.size = Vector2(PLATFORM_W, PLATFORM_H)
	rect.position = Vector2(-PLATFORM_W / 2, -PLATFORM_H / 2)
	respawn_node.add_child(rect)

	var body = StaticBody2D.new()
	body.name = "Body"
	body.collision_layer = 2
	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(PLATFORM_W, PLATFORM_H)
	body.add_child(shape)
	respawn_node.add_child(body)

	var tween = create_tween()
	tween.tween_property(respawn_node, "position:y", PLATFORM_Y_TARGET, PLATFORM_FALL_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	tween.tween_callback(_on_platform_landed)

func _on_platform_landed() -> void:
	respawn_life = RESPAWN_DURATION

	var platform_top = respawn_node.position.y - PLATFORM_H / 2
	stickman.global_position = Vector2(respawn_node.position.x, platform_top - 20)
	stickman.respawn()
	stickman.show()
	stickman.set_physics_process(true)

func update_respawn_platform(delta: float) -> void:
	respawn_life -= delta
	if respawn_life <= 0:
		if respawn_node:
			respawn_node.queue_free()
			respawn_node = null
		is_respawning = false
		return

	if respawn_life < FLASH_DURATION and respawn_node:
		var rect = respawn_node.get_node_or_null("Visual") as ColorRect
		if rect:
			var flash_hz = 5.0 + (FLASH_DURATION - respawn_life) * 15.0
			rect.visible = int(Time.get_ticks_msec() * flash_hz / 1000.0) % 2 == 0

func _on_resume_pressed() -> void:
	pause_menu.hide()
	get_tree().paused = false

func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
