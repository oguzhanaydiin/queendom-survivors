extends CharacterBody2D

@export var speed = 150.0
@export var shoot_interval = 0.8

var shoot_timer = 0.0
@onready var animated_sprite = $AnimatedSprite2D

func _ready():
	shoot_timer = shoot_interval

func _physics_process(delta):
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
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
	var angle = randf() * TAU
	ball.direction = Vector2.from_angle(angle)
	get_tree().current_scene.add_child(ball)

func _on_animated_sprite_2d_animation_finished():
	if animated_sprite.animation == "shoot":
		var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if direction != Vector2.ZERO:
			animated_sprite.play("walk")
		else:
			animated_sprite.play("idle")
