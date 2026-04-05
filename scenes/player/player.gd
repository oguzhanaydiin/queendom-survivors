extends CharacterBody2D

@export var max_hp: int = 100
@export var damage_cooldown: float = 1.0
@export var gem_attract_radius: float = 90.0

signal stats_changed(current_hp: int, p_max_hp: int, current_xp: int, xp_to_next: int, p_level: int)
signal player_died
signal damage_taken
signal weapons_changed(weapon_levels: Dictionary, attr_levels: Dictionary)
signal level_up_available(options: Array)

const WEAPON_ORDER = ["slime_ball", "fire_orb", "ice_shard", "thunder", "poison", "wind_blade"]
const ATTR_ORDER   = ["speed", "damage", "atk_spd", "area", "duration", "magnet"]

const WEAPON_INFO = {
	"slime_ball": {"name": "SLIME BALL", "icon": "◉",  "color": Color(0.25, 0.88, 0.35)},
	"fire_orb":   {"name": "FIRE ORB",   "icon": "◈",  "color": Color(0.95, 0.42, 0.08)},
	"ice_shard":  {"name": "ICE SHARD",  "icon": "❄",  "color": Color(0.42, 0.72, 1.00)},
	"thunder":    {"name": "THUNDER",    "icon": "⚡", "color": Color(0.92, 0.88, 0.12)},
	"poison":     {"name": "POISON",     "icon": "☁",  "color": Color(0.52, 0.88, 0.22)},
	"wind_blade": {"name": "WIND BLADE", "icon": "≋",  "color": Color(0.72, 0.92, 0.98)},
}
const ATTR_INFO = {
	"speed":    {"name": "SPEED",    "icon": "▶▶", "color": Color(0.25, 0.88, 0.35)},
	"damage":   {"name": "DAMAGE",   "icon": "⚔",  "color": Color(0.95, 0.42, 0.08)},
	"atk_spd":  {"name": "ATK SPD",  "icon": "↺",  "color": Color(0.42, 0.72, 1.00)},
	"area":     {"name": "AREA",     "icon": "◎",  "color": Color(0.92, 0.88, 0.12)},
	"duration": {"name": "DURATION", "icon": "⏱",  "color": Color(0.52, 0.88, 0.22)},
	"magnet":   {"name": "MAGNET",   "icon": "⊕",  "color": Color(0.72, 0.92, 0.98)},
}

# Upgrade descriptions: index = current_lv - 1  (before upgrade)
const _UPGRADE_DESC = {
	"slime_ball": ["Fires faster",     "2 balls spread",   "Faster + stronger", "3 balls spread",   "Max power!"],
	"fire_orb":   ["Unlocked!",        "Wider blast",      "More damage",       "Bigger area",      "Max power!"],
	"ice_shard":  ["Unlocked!",        "Slows enemies",    "Harder freeze",     "Pierces through",  "Max power!"],
	"thunder":    ["Unlocked!",        "Chains to 2",      "Chains to 3",       "More damage",      "Max power!"],
	"poison":     ["Unlocked!",        "Longer DoT",       "More stacks",       "Wider cloud",      "Max power!"],
	"wind_blade": ["Unlocked!",        "Pierces 2",        "Faster blades",     "Pierces 3",        "Max power!"],
	"speed":      ["+16 move speed",   "+16 move speed",   "+16 move speed",    "+16 move speed",   "+16 move speed"],
	"damage":     ["+10% damage",      "+10% damage",      "+10% damage",       "+10% damage",      "+10% damage"],
	"atk_spd":    ["-0.05s fire rate", "-0.05s fire rate", "-0.05s fire rate",  "-0.05s fire rate", "-0.05s fire rate"],
	"area":       ["+15% area",        "+15% area",        "+15% area",         "+15% area",        "+15% area"],
	"duration":   ["+20% duration",    "+20% duration",    "+20% duration",     "+20% duration",    "+20% duration"],
	"magnet":     ["+20 pickup range", "+20 pickup range", "+20 pickup range",  "+20 pickup range", "+20 pickup range"],
}

const _BASE_SPEED    := 320.0
const _BASE_INTERVAL := 0.8

var weapon_levels: Dictionary = {
	"slime_ball": 1, "fire_orb": 0, "ice_shard": 0,
	"thunder": 0, "poison": 0, "wind_blade": 0,
}
var attr_levels: Dictionary = {
	"speed": 1, "damage": 0, "atk_spd": 0,
	"area": 0, "duration": 0, "magnet": 0,
}

var speed: float          = _BASE_SPEED
var shoot_interval: float = _BASE_INTERVAL
var shoot_timer:    float = 0.0
var current_hp: int
var current_xp: int = 0
var xp_to_next_level: int = 100
var level: int = 1
var damage_timer: float = 0.0
var _dead: bool = false

# Level-up queue so multiple XP events don't stack broken UI
var _levelup_queue: int = 0
var _levelup_busy:  bool = false

@onready var animated_sprite = $AnimatedSprite2D

func _ready():
	add_to_group("player")
	current_hp = max_hp
	collision_layer = 1
	collision_mask = 2
	_register_movement_actions()
	_apply_weapon_effects()

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
	var aim = get_global_mouse_position() - global_position
	if aim.length_squared() < 1.0:
		aim = Vector2.RIGHT
	aim = aim.normalized()

	var sb_lv: int = weapon_levels.get("slime_ball", 1)
	var ball_count := 1 if sb_lv < 3 else (2 if sb_lv < 5 else 3)
	var ball_speed := 300.0 + (sb_lv - 1) * 20.0
	var spread     := deg_to_rad(14.0)

	var offsets: Array = [0.0]
	if ball_count == 2:
		offsets = [-spread * 0.5, spread * 0.5]
	elif ball_count == 3:
		offsets = [-spread, 0.0, spread]

	for angle_offset in offsets:
		var ball = ball_scene.instantiate()
		ball.global_position = global_position
		ball.direction = aim.rotated(angle_offset)
		ball.speed = ball_speed
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
	_levelup_queue += 1
	if not _levelup_busy:
		_show_next_levelup()

func _show_next_levelup() -> void:
	if _levelup_queue <= 0:
		_levelup_busy = false
		return
	_levelup_busy = true
	_levelup_queue -= 1
	level_up_available.emit(_get_level_up_options())

func _get_level_up_options() -> Array:
	var opts: Array = []
	for key in WEAPON_ORDER:
		var lv: int = weapon_levels.get(key, 0)
		if lv >= 1 and lv < 6:
			opts.append(_make_option(key, "weapon", lv))
	for key in ATTR_ORDER:
		var lv: int = attr_levels.get(key, 0)
		if lv >= 1 and lv < 6:
			opts.append(_make_option(key, "attr", lv))
	return opts

func _make_option(key: String, kind: String, current_lv: int) -> Dictionary:
	var info = WEAPON_INFO[key] if kind == "weapon" else ATTR_INFO[key]
	var descs: Array = _UPGRADE_DESC.get(key, [])
	var desc_idx: int = clamp(current_lv - 1, 0, descs.size() - 1)
	var icon_col: int = WEAPON_ORDER.find(key) if kind == "weapon" else ATTR_ORDER.find(key)
	return {
		"id":         key,
		"type":       kind,
		"name":       info["name"],
		"icon":       info["icon"],
		"color":      info["color"],
		"current_lv": current_lv,
		"desc":       descs[desc_idx] if descs.size() > 0 else "",
		"icon_col":   icon_col,
		"icon_row":   0 if kind == "weapon" else 1,
	}

func apply_upgrade(upgrade_id: String) -> void:
	if upgrade_id in weapon_levels:
		weapon_levels[upgrade_id] = min(6, max(1, weapon_levels[upgrade_id] + 1))
	elif upgrade_id in attr_levels:
		attr_levels[upgrade_id] = min(6, max(1, attr_levels[upgrade_id] + 1))
	_apply_weapon_effects()
	weapons_changed.emit(weapon_levels, attr_levels)
	# Process any queued level-ups after the current upgrade is handled
	_levelup_busy = false
	_show_next_levelup()

func _apply_weapon_effects() -> void:
	var sb_lv:  int = weapon_levels.get("slime_ball", 1)
	var spd_lv: int = attr_levels.get("speed", 1)
	# Shoot interval scales with slime ball level
	shoot_interval = max(0.4, _BASE_INTERVAL - (sb_lv - 1) * 0.06)
	shoot_timer    = min(shoot_timer, shoot_interval)
	# Movement speed scales with speed attribute level
	speed = _BASE_SPEED + (spd_lv - 1) * 16.0

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
