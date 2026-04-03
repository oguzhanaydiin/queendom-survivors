extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_interval = 2.0

var spawn_timer = 0.0
var _hud: CanvasLayer
var _game_over: bool = false

func _ready():
	spawn_timer = spawn_interval
	_setup_hud()

func _setup_hud() -> void:
	var hud_script = preload("res://scenes/hud/hud.gd")
	_hud = CanvasLayer.new()
	_hud.set_script(hud_script)
	_hud.name = "HUD"
	add_child(_hud)

	var player = get_node("Player")
	player.stats_changed.connect(_hud.update_stats)
	player.player_died.connect(_on_player_died)
	player.damage_taken.connect(_hud.flash_damage)
	_hud.update_stats(player.current_hp, player.max_hp, player.current_xp, player.xp_to_next_level, player.level)

func _on_player_died() -> void:
	_game_over = true
	_hud.show_game_over()
	get_tree().paused = true

func _process(delta):
	if _game_over:
		return
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
