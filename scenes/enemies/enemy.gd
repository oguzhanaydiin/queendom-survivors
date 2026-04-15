extends CharacterBody2D

@export var speed = 100.0
@export var xp_value: int = 10
@export var damage_amount: int = 10
@export var damage_interval: float = 1.0
@export var melee_range: float = 120.0
@export var max_hp: float = 12.0

var is_dying = false
var dmg_timer: float = 0.0
var current_hp: float = 0.0

@onready var animated_sprite = $AnimatedSprite2D

func _ready():
	add_to_group("enemies")
	# Collide with player (layer 1) only — enemies ignore each other
	collision_mask = 1
	current_hp = max_hp

func take_damage(amount: float) -> void:
	if is_dying or amount <= 0.0:
		return
	current_hp -= amount
	if current_hp <= 0.0:
		die()

func _physics_process(delta):
	if is_dying:
		return

	if dmg_timer > 0:
		dmg_timer -= delta

	var player = get_tree().get_first_node_in_group("player")
	if player:
		var dir = (player.global_position - global_position).normalized()
		velocity = dir * speed
		if dir.x < 0:
			animated_sprite.flip_h = true
		elif dir.x > 0:
			animated_sprite.flip_h = false
		move_and_slide()

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

	_spawn_xp_gem()
	queue_free()

func _spawn_xp_gem() -> void:
	var gem_script = preload("res://scenes/xp_gem/xp_gem.gd")
	var gem = Node2D.new()
	gem.set_script(gem_script)
	gem.xp_amount = xp_value
	gem.position = global_position + Vector2(0, 28)
	get_tree().current_scene.add_child(gem)
