extends CharacterBody2D

@export var speed = 60.0
var is_dying = false

@onready var animated_sprite = $AnimatedSprite2D

func _ready():
	add_to_group("enemies")
	animated_sprite.play("walk")

func _physics_process(_delta):
	if is_dying:
		return
	var player = get_tree().current_scene.get_node("Player")
	if player:
		var dir = (player.global_position - global_position).normalized()
		velocity = dir * speed
		if dir.x < 0:
			animated_sprite.flip_h = true
		elif dir.x > 0:
			animated_sprite.flip_h = false
		move_and_slide()

func die():
	if is_dying:
		return
	is_dying = true
	velocity = Vector2.ZERO
	collision_layer = 0
	animated_sprite.sprite_frames.set_animation_loop("death", false)
	animated_sprite.play("death")
	await animated_sprite.animation_finished
	queue_free()
