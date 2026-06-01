extends CharacterBody2D

const SPEED = 400.0
const JUMP_VELOCITY = -950.0
const GRAVITY = 2800.0
const MAX_JUMPS = 2

const FRAME_W = 64
const SPRITE_DIR = "res://Sprites/LPC/split/standard/"

var facing_right := true
var jump_was_pressed := false
var jump_count := 0
var platform_mask := 0
var last_down := false
var drop_until := 0.0

var action_locked := false
var last_melee := false
var last_ranged := false
var last_cast := false
var last_dodge := false

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
	_build_sprite_frames()
	anim.play("idle")
	platform_mask = 1 | 2

func _build_sprite_frames() -> void:
	var frames = SpriteFrames.new()
	for name in ANIM_DATA:
		var d = ANIM_DATA[name]
		var tex = load(SPRITE_DIR + d.file)
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

	var left = Input.is_key_pressed(KEY_A)
	var right = Input.is_key_pressed(KEY_D)

	var h_dir := 0.0
	if left:
		h_dir -= 1.0
	if right:
		h_dir += 1.0

	var jump_pressed := Input.is_key_pressed(KEY_SPACE)
	if jump_pressed and not jump_was_pressed and jump_count < MAX_JUMPS:
		velocity.y = JUMP_VELOCITY
		jump_count += 1
	jump_was_pressed = jump_pressed
	if is_on_floor():
		jump_count = 0

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

	anim.flip_h = facing_right

	if action_locked:
		if not anim.is_playing():
			action_locked = false
		else:
			return

	var melee_now = Input.is_key_pressed(KEY_J)
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

	if dodge:
		_start_action("dodge")
	elif melee:
		_start_action("attack")
	elif ranged:
		_start_action("ranged")
	elif cast:
		_start_action("spell")
	elif anim.animation == "death":
		pass
	elif not is_on_floor():
		_play_anim("jump")
	elif h_dir != 0:
		_play_anim("run")
	else:
		_play_anim("idle")


func _start_action(name: String) -> void:
	action_locked = true
	anim.play(name)
	anim.advance(0)

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
