extends Node2D

# Assign in the editor (or from a character-select / stage-select screen).
@export var character_scene: PackedScene
@export var map_scene: PackedScene
## Seconds between spawn ticks at run start (gets faster toward spawn_interval_min).
@export var spawn_interval: float = 2.0
@export var spawn_interval_min: float = 0.45
## After this many seconds, spawn interval reaches spawn_interval_min.
@export var spawn_pressure_ramp_sec: float = 600.0

## Tier 1 = acorn only before this; then tier 2 (maple) mixes in.
@export var maple_unlock_sec: float = 60.0
## Seconds after maple_unlock_sec over which P(maple | not mushroom) rises to maple_weight_max.
@export var maple_mix_ramp_sec: float = 140.0
## Among acorn+maple spawns, max chance to pick maple once unlocked (tier 2).
@export var maple_weight_max: float = 0.52

## Tier 3 (mushroom) starts after this (seconds). Tuned for ~10 min first-map pacing.
@export var mushroom_unlock_sec: float = 300.0
## Seconds after mushroom_unlock_sec over which P(mushroom) rises to mushroom_weight_max.
@export var mushroom_mix_ramp_sec: float = 280.0
## Max overall chance to spawn mushroom (tier 3); remainder is acorn/maple split by tier 2 curve.
@export var mushroom_weight_max: float = 0.4

const AIM_OFFSET_MAX := 15.0   # px the camera shifts toward the mouse
const AIM_LERP_SPEED := 5.0
const AIM_DEAD_ZONE  := 0.65   # fraction of half-screen with no effect

const ACORN_SCENE: PackedScene = preload("res://scenes/enemies/acorn.tscn")
const MAPLE_SCENE: PackedScene = preload("res://scenes/enemies/maple.tscn")
const MUSHROOM_SCENE: PackedScene = preload("res://scenes/enemies/mushroom.tscn")

var _player: Node2D
var _map: BaseMap
var _camera: Camera2D
var _hud: CanvasLayer
var _spawn_timer: float
var _game_over: bool = false
var _run_time: float = 0.0
var _pause_menu_open: bool = false


func _ready() -> void:
	_register_pause_action()
	_spawn_timer = _spawn_period_sec()
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
	_hud.configure_pause_controls(Callable(self, "_toggle_pause"))

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

func _register_pause_action() -> void:
	if InputMap.has_action("pause_game"):
		return

	InputMap.add_action("pause_game")
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	InputMap.action_add_event("pause_game", ev)


# ---------------------------------------------------------------------------
# Game loop
# ---------------------------------------------------------------------------

func _toggle_pause() -> void:
	if _pause_menu_open:
		_resume_game()
	else:
		_pause_game()

func _on_player_died() -> void:
	_pause_menu_open = false
	if _hud:
		_hud.hide_pause_menu()
	_game_over = true
	_hud.show_game_over()
	get_tree().paused = true

func _on_level_up_available(options: Array) -> void:
	_hud.show_level_up_choice(options, func(id: String): _player.apply_upgrade(id))

func _pause_game() -> void:
	if _pause_menu_open or _game_over:
		return
	_pause_menu_open = true
	_hud.show_pause_menu(Callable(self, "_resume_game"), Callable(self, "_restart_run"))
	get_tree().paused = true

func _resume_game() -> void:
	if not _pause_menu_open:
		return
	_pause_menu_open = false
	if _hud:
		_hud.hide_pause_menu()
	get_tree().paused = false

func _restart_run() -> void:
	_pause_menu_open = false
	if _hud:
		_hud.hide_pause_menu()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _process(delta: float) -> void:
	if _game_over or get_tree().paused:
		return
	_run_time += delta
	_update_camera_aim(delta)
	_spawn_timer -= delta
	if _spawn_timer <= 0:
		_spawn_timer = _spawn_period_sec()
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
	_camera.position = _camera.position.lerp(target, delta * AIM_LERP_SPEED).round()


func _aim_axis(v: float) -> float:
	var s := signf(v)
	var a := absf(v)
	if a <= AIM_DEAD_ZONE:
		return 0.0
	return s * (a - AIM_DEAD_ZONE) / (1.0 - AIM_DEAD_ZONE)


func _spawn_pressure_t() -> float:
	if spawn_pressure_ramp_sec <= 0.0:
		return 1.0
	return smoothstep(0.0, spawn_pressure_ramp_sec, _run_time)


func _spawn_period_sec() -> float:
	var t := _spawn_pressure_t()
	return lerpf(spawn_interval, spawn_interval_min, t)


func _tier2_share_given_not_mushroom() -> float:
	if _run_time < maple_unlock_sec:
		return 0.0
	var mt := 0.0
	if maple_mix_ramp_sec > 0.0:
		mt = smoothstep(0.0, maple_mix_ramp_sec, _run_time - maple_unlock_sec)
	return mt * clampf(maple_weight_max, 0.0, 1.0)


func _tier3_mushroom_share() -> float:
	if _run_time < mushroom_unlock_sec:
		return 0.0
	var ut := 0.0
	if mushroom_mix_ramp_sec > 0.0:
		ut = smoothstep(0.0, mushroom_mix_ramp_sec, _run_time - mushroom_unlock_sec)
	return ut * clampf(mushroom_weight_max, 0.0, 1.0)


func _pick_enemy_scene() -> PackedScene:
	var p_mushroom := _tier3_mushroom_share()
	if randf() < p_mushroom:
		return MUSHROOM_SCENE
	var p_maple := _tier2_share_given_not_mushroom()
	if randf() < p_maple:
		return MAPLE_SCENE
	return ACORN_SCENE


func _spawn_enemy() -> void:
	if not _camera:
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

	var enemy := _pick_enemy_scene().instantiate()
	enemy.global_position = spawn_pos
	add_child(enemy)
