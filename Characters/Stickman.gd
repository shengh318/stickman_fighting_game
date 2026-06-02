extends CharacterBody2D

const SPEED = 400.0
const JUMP_VELOCITY = -950.0
const GRAVITY = 2800.0
const MAX_JUMPS = 2

const FRAME_W = 64
var sprite_dir := "res://Sprites/LPC/split/standard/"

@export var is_player := true
var facing_right := true
var jump_was_pressed := false
var jump_count := 0
var platform_mask := 0
var last_down := false
var drop_until := 0.0

var action_locked := false
var respawn_lock := false
var respawn_landed := false
var last_melee := false
var last_ranged := false
var last_cast := false
var last_dodge := false

var weapon: Node2D
var weapon_pivot: Node2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

# Each animation uses row 1 (left-facing profile) from its split PNG,
# or the only row for single-row files. Flipped horizontally when moving right.
const ANIM_DATA = {
	"idle":   { "file": "idle.png",   "y": 71,  "h": 56, "f": 2,  "loop": true,  "dur": 0.80 },
	"run":    { "file": "run.png",    "y": 71,  "h": 56, "f": 8,  "loop": true,  "dur": 0.30 },
	"jump":   { "file": "jump.png",   "y": 69,  "h": 58, "f": 5,  "loop": true,  "dur": 0.25 },
	"attack": { "file": "slash.png",  "y": 72,  "h": 56, "f": 6,  "loop": false, "dur": 0.10 },
	"ranged": { "file": "shoot.png",  "y": 72,  "h": 56, "f": 13, "loop": false, "dur": 0.12 },
	"spell":  { "file": "spellcast.png", "y": 72, "h": 56, "f": 7,  "loop": false, "dur": 0.15 },
	"hurt":   { "file": "hurt.png",   "y": 12,  "h": 52, "f": 6,  "loop": false, "dur": 0.10 },
	"dodge":  { "file": "climb.png",  "y": 8,   "h": 54, "f": 6,  "loop": false, "dur": 0.08 },
	"death":  { "file": "hurt.png",   "y": 12,  "h": 52, "f": 6,  "loop": false, "dur": 0.15 },
}

func _ready() -> void:
	if not is_player:
		sprite_dir = "res://Sprites/LPC/split_p2/standard/"
		facing_right = false
	_build_sprite_frames()
	anim.play("idle")
	platform_mask = 1 | 2
	if not is_player:
		anim.flip_h = false
	_create_weapon()

func _build_sprite_frames() -> void:
	var frames = SpriteFrames.new()
	for name in ANIM_DATA:
		var d = ANIM_DATA[name]
		var tex = load(sprite_dir + d.file)
		if not tex:
			continue
		frames.add_animation(name)
		for i in d.f:
			var at = AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * FRAME_W, d.y, FRAME_W, d.h)
			frames.add_frame(name, at, d.dur)
		frames.set_animation_loop(name, d.loop)

	anim.sprite_frames = frames
	anim.play("idle")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if is_on_floor():
		jump_count = 0

	var h_dir := 0.0

	if is_player and not respawn_lock:
		var left = Input.is_key_pressed(KEY_A)
		var right = Input.is_key_pressed(KEY_D)

		if left:
			h_dir -= 1.0
		if right:
			h_dir += 1.0

		var jump_pressed := Input.is_key_pressed(KEY_SPACE)
		if jump_pressed and not jump_was_pressed and jump_count < MAX_JUMPS:
			velocity.y = JUMP_VELOCITY
			jump_count += 1
		jump_was_pressed = jump_pressed

		if h_dir != 0:
			velocity.x = h_dir * SPEED
			facing_right = h_dir > 0
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

		var down_pressed := Input.is_key_pressed(KEY_S)
		var down_just_pressed := down_pressed and not last_down
		last_down = down_pressed

		if down_just_pressed and is_on_floor():
			drop_until = Time.get_ticks_msec() + 300.0

	var should_drop := Time.get_ticks_msec() < drop_until

	if velocity.y < 0 or should_drop:
		collision_mask = 1
	else:
		collision_mask = platform_mask

	move_and_slide()

	if respawn_lock and is_on_floor() and not respawn_landed:
		respawn_landed = true
		get_tree().create_timer(1.0).timeout.connect(func():
			respawn_lock = false
		)

	anim.flip_h = facing_right
	if weapon:
		weapon.scale.x = 1 if facing_right else -1

	if action_locked:
		if not anim.is_playing():
			action_locked = false
		else:
			return

	if is_player:
		var melee_now = Input.is_key_pressed(KEY_P)
		var ranged_now = Input.is_key_pressed(KEY_K)
		var cast_now = Input.is_key_pressed(KEY_L)
		var dodge_now = Input.is_key_pressed(KEY_H)

		var melee = melee_now and not last_melee
		var ranged = ranged_now and not last_ranged
		var cast = cast_now and not last_cast
		var dodge = dodge_now and not last_dodge

		last_melee = melee_now
		last_ranged = ranged_now
		last_cast = cast_now
		last_dodge = dodge_now

		if not respawn_lock and dodge:
			_start_action("dodge")
		elif not respawn_lock and melee:
			_start_action("attack")
		elif not respawn_lock and ranged:
			_start_action("ranged")
		elif not respawn_lock and cast:
			_start_action("spell")

	if anim.animation == "death":
		pass
	elif respawn_lock:
		_play_anim("idle")
	elif not is_on_floor():
		_play_anim("jump")
	elif h_dir != 0:
		_play_anim("run")
	else:
		_play_anim("idle")


func _create_weapon() -> void:
	weapon = Node2D.new()
	weapon.name = "Weapon"
	weapon.position = Vector2(10, -6)
	add_child(weapon)

	weapon_pivot = Node2D.new()
	weapon_pivot.name = "Pivot"
	weapon_pivot.rotation = -0.4
	weapon.add_child(weapon_pivot)

	var blade = ColorRect.new()
	blade.name = "Blade"
	blade.size = Vector2(4, 34)
	blade.color = Color(0.75, 0.75, 0.85)
	blade.position = Vector2(-2, -34)
	weapon_pivot.add_child(blade)

	var guard = ColorRect.new()
	guard.name = "Guard"
	guard.size = Vector2(10, 2)
	guard.color = Color(0.4, 0.3, 0.2)
	guard.position = Vector2(-5, -2)
	weapon_pivot.add_child(guard)

	var handle = ColorRect.new()
	handle.name = "Handle"
	handle.size = Vector2(3, 7)
	handle.color = Color(0.3, 0.2, 0.1)
	handle.position = Vector2(-1, 0)
	weapon_pivot.add_child(handle)

func _swing_weapon() -> void:
	if not weapon_pivot:
		return
	weapon_pivot.rotation = -1.8
	var tween = create_tween()
	tween.tween_property(weapon_pivot, "rotation", 1.5, 0.12).set_ease(Tween.EASE_OUT)

func _start_action(name: String) -> void:
	action_locked = true
	anim.play(name)
	anim.advance(0)
	if name == "attack":
		_swing_weapon()

func _play_anim(name: String) -> void:
	if anim.animation != name:
		anim.play(name)

func take_damage() -> void:
	if action_locked:
		return
	if anim.animation == "death":
		return
	_start_action("hurt")

func die() -> void:
	action_locked = true
	anim.play("death")
	anim.advance(0)

func respawn() -> void:
	velocity = Vector2.ZERO
	jump_count = 0
	facing_right = true
	action_locked = false
	respawn_lock = true
	respawn_landed = false
	drop_until = 0.0
	last_down = false
	jump_was_pressed = false
	last_melee = false
	last_ranged = false
	last_cast = false
	last_dodge = false
	anim.play("idle")
	anim.flip_h = facing_right
	anim.frame = 0
	if weapon:
		weapon_pivot.rotation = -0.4
		weapon.scale.x = 1 if facing_right else -1
