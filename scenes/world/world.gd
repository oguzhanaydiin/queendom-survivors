extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_interval = 2.0

var spawn_timer = 0.0

func _ready():
	spawn_timer = spawn_interval

func _process(delta):
	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_timer = spawn_interval
		spawn_enemy()

func spawn_enemy():
	if not enemy_scene:
		return
	var enemy = enemy_scene.instantiate()
	var viewport_size = get_viewport().get_visible_rect().size
	var spawn_pos = Vector2.ZERO
	var side = randi() % 4
	var margin = 50
	match side:
		0:
			spawn_pos = Vector2(randf_range(0, viewport_size.x), -margin)
		1:
			spawn_pos = Vector2(randf_range(0, viewport_size.x), viewport_size.y + margin)
		2:
			spawn_pos = Vector2(-margin, randf_range(0, viewport_size.y))
		3:
			spawn_pos = Vector2(viewport_size.x + margin, randf_range(0, viewport_size.y))
	enemy.global_position = spawn_pos
	add_child(enemy)
