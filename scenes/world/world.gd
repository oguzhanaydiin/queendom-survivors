extends Node2D

# Assign in the editor (or from a character-select / stage-select screen).
@export var character_scene: PackedScene
@export var map_scene: PackedScene
@export var enemy_scene: PackedScene
@export var spawn_interval: float = 2.0

const AIM_OFFSET_MAX := 15.0   # px the camera shifts toward the mouse
const AIM_LERP_SPEED := 5.0
const AIM_DEAD_ZONE  := 0.65   # fraction of half-screen with no effect

var _player: Node2D
var _map: BaseMap
var _camera: Camera2D
var _hud: CanvasLayer
var _spawn_timer: float
var _game_over: bool = false


func _ready() -> void:
	_spawn_timer = spawn_interval
	_spawn_map()
	_spawn_player()
	_setup_camera()
	_setup_hud()


# ---------------------------------------------------------------------------
# Setup helpers
# ---------------------------------------------------------------------------

func _spawn_map() -> void:
	if not map_scene:
		push_error("World: no map_scene assigned")
		return
	_map = map_scene.instantiate()
	add_child(_map)
	move_child(_map, 0)  # keep map behind everything else


func _spawn_player() -> void:
	if not character_scene:
		push_error("World: no character_scene assigned")
		return
	_player = character_scene.instantiate()
	_player.name = "Player"
	_player.position = Vector2.ZERO
	add_child(_player)

	if _map:
		_map.initialize(_player)


func _setup_camera() -> void:
	_camera = $Camera2D
	# Reparent the camera to the player so it follows automatically.
	# When the player is swapped between runs, call this again with the new player.
	_camera.reparent(_player, false)
	_camera.position = Vector2.ZERO


func _setup_hud() -> void:
	var hud_script := preload("res://scenes/hud/hud.gd")
	_hud = CanvasLayer.new()
	_hud.set_script(hud_script)
	_hud.name = "HUD"
	add_child(_hud)

	_player.stats_changed.connect(_hud.update_stats)
	_player.player_died.connect(_on_player_died)
	_player.damage_taken.connect(_hud.flash_damage)
	_player.weapons_changed.connect(_hud.update_weapons)
	_player.level_up_available.connect(_on_level_up_available)
	_hud.update_stats(
		_player.current_hp, _player.max_hp,
		_player.current_xp, _player.xp_to_next_level,
		_player.level
	)
	_hud.update_weapons(_player.weapon_levels, _player.attr_levels)


# ---------------------------------------------------------------------------
# Game loop
# ---------------------------------------------------------------------------

func _on_player_died() -> void:
	_game_over = true
	_hud.show_game_over()
	get_tree().paused = true

func _on_level_up_available(options: Array) -> void:
	_hud.show_level_up_choice(options, func(id: String): _player.apply_upgrade(id))


func _process(delta: float) -> void:
	if _game_over:
		return
	_update_camera_aim(delta)
	_spawn_timer -= delta
	if _spawn_timer <= 0:
		_spawn_timer = spawn_interval
		_spawn_enemy()


func _update_camera_aim(delta: float) -> void:
	var vp_size  := get_viewport().get_visible_rect().size
	var mouse_vp := get_viewport().get_mouse_position()
	var raw      := (mouse_vp - vp_size * 0.5) / (vp_size * 0.5)
	# apply dead zone per axis: no movement until mouse passes AIM_DEAD_ZONE
	var norm := Vector2(
		_aim_axis(raw.x),
		_aim_axis(raw.y)
	).limit_length(1.0)
	var target := norm * AIM_OFFSET_MAX
	_camera.position = _camera.position.lerp(target, delta * AIM_LERP_SPEED)


func _aim_axis(v: float) -> float:
	var s := signf(v)
	var a := absf(v)
	if a <= AIM_DEAD_ZONE:
		return 0.0
	return s * (a - AIM_DEAD_ZONE) / (1.0 - AIM_DEAD_ZONE)


func _spawn_enemy() -> void:
	if not enemy_scene or not _camera:
		return

	var vp_size   := get_viewport().get_visible_rect().size
	var cam_center := _camera.global_position
	var margin    := 80.0

	var half_w := vp_size.x * 0.5
	var half_h := vp_size.y * 0.5

	var spawn_pos := Vector2.ZERO
	match randi() % 4:
		0: spawn_pos = Vector2(cam_center.x + randf_range(-half_w, half_w), cam_center.y - half_h - margin)
		1: spawn_pos = Vector2(cam_center.x + randf_range(-half_w, half_w), cam_center.y + half_h + margin)
		2: spawn_pos = Vector2(cam_center.x - half_w - margin, cam_center.y + randf_range(-half_h, half_h))
		3: spawn_pos = Vector2(cam_center.x + half_w + margin, cam_center.y + randf_range(-half_h, half_h))

	var enemy := enemy_scene.instantiate()
	enemy.global_position = spawn_pos
	add_child(enemy)
