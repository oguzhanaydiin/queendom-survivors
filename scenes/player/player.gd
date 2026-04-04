extends CharacterBody2D

@export var speed = 320.0
@export var shoot_interval = 0.8
@export var max_hp: int = 100
@export var damage_cooldown: float = 1.0
@export var gem_attract_radius: float = 90.0

signal stats_changed(current_hp: int, p_max_hp: int, current_xp: int, xp_to_next: int, p_level: int)
signal player_died
signal damage_taken

var shoot_timer = 0.0
var current_hp: int
var current_xp: int = 0
var xp_to_next_level: int = 100
var level: int = 1
var damage_timer: float = 0.0
var _dead: bool = false

@onready var animated_sprite = $AnimatedSprite2D

func _ready():
	add_to_group("player")
	shoot_timer = shoot_interval
	current_hp = max_hp
	collision_layer = 1
	collision_mask = 2  # physically collide with orcs (layer 2)
	_register_movement_actions()

func _register_movement_actions() -> void:
	var defs = {
		"move_left":  [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up":    [KEY_W, KEY_UP],
		"move_down":  [KEY_S, KEY_DOWN],
	}
	for action in defs:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for key in defs[action]:
				var ev = InputEventKey.new()
				ev.keycode = key
				InputMap.action_add_event(action, ev)

func _get_input_direction() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func _physics_process(delta):
	if _dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if damage_timer > 0:
		damage_timer -= delta

	var direction = _get_input_direction()
	velocity = direction * speed
	move_and_slide()

	if direction.x < 0:
		animated_sprite.flip_h = true
	elif direction.x > 0:
		animated_sprite.flip_h = false

	if animated_sprite.animation != "shoot":
		if direction != Vector2.ZERO:
			if animated_sprite.animation != "walk":
				animated_sprite.play("walk")
		else:
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")

	shoot_timer -= delta
	if shoot_timer <= 0:
		shoot_timer = shoot_interval
		shoot()

func shoot():
	animated_sprite.play("shoot")
	var ball_scene = preload("res://scenes/slime_ball/slime_ball.tscn")
	var ball = ball_scene.instantiate()
	ball.global_position = global_position
	var aim = get_global_mouse_position() - global_position
	if aim.length_squared() < 1.0:
		aim = Vector2.RIGHT
	ball.direction = aim.normalized()
	get_tree().current_scene.add_child(ball)

func take_damage(amount: int):
	if damage_timer > 0 or _dead:
		return
	damage_timer = damage_cooldown
	current_hp = max(0, current_hp - amount)
	damage_taken.emit()
	stats_changed.emit(current_hp, max_hp, current_xp, xp_to_next_level, level)
	if current_hp <= 0:
		_on_player_died()

func add_xp(amount: int):
	current_xp += amount
	while current_xp >= xp_to_next_level:
		current_xp -= xp_to_next_level
		_level_up()
	stats_changed.emit(current_hp, max_hp, current_xp, xp_to_next_level, level)

func _level_up():
	level += 1
	xp_to_next_level = 100 + (level - 1) * 50

func _on_player_died():
	_dead = true
	player_died.emit()

func _on_animated_sprite_2d_animation_finished():
	if animated_sprite.animation == "shoot":
		var direction = _get_input_direction()
		if direction != Vector2.ZERO:
			animated_sprite.play("walk")
		else:
			animated_sprite.play("idle")
