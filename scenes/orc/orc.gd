extends CharacterBody2D

@export var speed = 60.0
@export var xp_value: int = 10
@export var damage_amount: int = 10
@export var damage_interval: float = 1.0
@export var melee_range: float = 120.0

var is_dying = false
var dmg_timer: float = 0.0

@onready var animated_sprite = $AnimatedSprite2D

func _ready():
	add_to_group("enemies")
	animated_sprite.play("walk")
	# Collide with player (layer 1) only — orcs are ghosts to each other
	collision_mask = 1

func _physics_process(delta):
	if is_dying:
		return

	if dmg_timer > 0:
		dmg_timer -= delta

	var player = get_tree().current_scene.get_node_or_null("Player")
	if player:
		var dir = (player.global_position - global_position).normalized()
		velocity = dir * speed
		if dir.x < 0:
			animated_sprite.flip_h = true
		elif dir.x > 0:
			animated_sprite.flip_h = false
		move_and_slide()

		# Distance-based damage: no physics layer needed for detection
		var dist = global_position.distance_to(player.global_position)
		if dist < melee_range and dmg_timer <= 0:
			dmg_timer = damage_interval
			player.take_damage(damage_amount)

func die():
	if is_dying:
		return
	is_dying = true
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0

	animated_sprite.sprite_frames.set_animation_loop("death", false)
	animated_sprite.play("death")
	await animated_sprite.animation_finished

	# Gem drops right as the orc disappears
	_spawn_xp_gem()
	queue_free()

func _spawn_xp_gem() -> void:
	var gem_script = preload("res://scenes/xp_gem/xp_gem.gd")
	var gem = Node2D.new()
	gem.set_script(gem_script)
	gem.xp_amount = xp_value
	# Offset to visual center of the sprite
	gem.position = global_position + Vector2(0, 28)
	get_tree().current_scene.add_child(gem)
