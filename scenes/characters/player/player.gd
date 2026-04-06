extends CharacterBody2D

@export var max_hp: int = 100
@export var damage_cooldown: float = 1.0
@export var gem_attract_radius: float = 90.0

signal stats_changed(current_hp: int, p_max_hp: int, current_xp: int, xp_to_next: int, p_level: int)
signal player_died
signal damage_taken
signal weapons_changed(weapon_levels: Dictionary, attr_levels: Dictionary)
signal level_up_available(options: Array)

const WEAPON_ORDER = ["ice_cream", "toffee_bomb", "rock_candy", "lollipop", "cotton_candy", "candy_cane"]
const ATTR_ORDER   = ["speed", "damage", "atk_spd", "area", "duration", "magnet"]

const WEAPON_INFO = {
	"ice_cream":    {"name": "ICE CREAM",    "icon": "◉",  "color": Color(0.98, 0.76, 0.62)},
	"toffee_bomb":  {"name": "TOFFEE BOMB",  "icon": "◈",  "color": Color(0.90, 0.62, 0.10)},
	"rock_candy":   {"name": "ROCK CANDY",   "icon": "◆",  "color": Color(0.42, 0.72, 1.00)},
	"lollipop":     {"name": "LOLLIPOP",     "icon": "⊙",  "color": Color(0.98, 0.25, 0.72)},
	"cotton_candy": {"name": "COTTON CANDY", "icon": "☁",  "color": Color(0.98, 0.72, 0.88)},
	"candy_cane":   {"name": "CANDY CANE",   "icon": "∩",  "color": Color(0.95, 0.18, 0.18)},
}
const ATTR_INFO = {
	"speed":    {"name": "SPEED",    "icon": "▶▶", "color": Color(0.98, 0.76, 0.62)},
	"damage":   {"name": "DAMAGE",   "icon": "⚔",  "color": Color(0.90, 0.62, 0.10)},
	"atk_spd":  {"name": "ATK SPD",  "icon": "↺",  "color": Color(0.42, 0.72, 1.00)},
	"area":     {"name": "AREA",     "icon": "◎",  "color": Color(0.98, 0.25, 0.72)},
	"duration": {"name": "DURATION", "icon": "⏱",  "color": Color(0.98, 0.72, 0.88)},
	"magnet":   {"name": "MAGNET",   "icon": "⊕",  "color": Color(0.95, 0.18, 0.18)},
}

# What each weapon/attribute IS (shown when unlocking at lv 0 → 1)
const _WEAPON_WHAT: Dictionary = {
	"ice_cream":    "Launches ice cream cones that splat enemies",
	"toffee_bomb":  "Drops sticky toffee bombs that explode on impact",
	"rock_candy":   "Fires crystal shards in all directions",
	"lollipop":     "Rainbow lollipops spin around you striking enemies",
	"cotton_candy": "A sweet pink cloud floats nearby poisoning foes",
	"candy_cane":   "A candy cane sweeps in a wide slashing arc",
}
const _ATTR_WHAT: Dictionary = {
	"speed":    "Move faster across the battlefield",
	"damage":   "Deal more damage with every attack",
	"atk_spd":  "Attack more frequently",
	"area":     "All attacks cover a larger area",
	"duration": "Weapon effects last longer",
	"magnet":   "Attract gems from much further away",
}

# Upgrade descriptions: index = current_lv - 1  (before upgrade)
const _UPGRADE_DESC = {
	"ice_cream":    ["Fires faster",      "2 cones spread",    "Faster + stronger", "3 cones spread",   "Max sugar!"],
	"toffee_bomb":  ["Unlocked!",         "Bigger explosion",  "More damage",       "Faster drops",     "Max sugar!"],
	"rock_candy":   ["Unlocked!",         "Slows enemies",     "More crystals",     "Pierces through",  "Max sugar!"],
	"lollipop":     ["Unlocked!",         "Wider spin",        "Faster spin",       "More lollipops",   "Max sugar!"],
	"cotton_candy": ["Unlocked!",         "Bigger cloud",      "Thicker cloud",     "Wider reach",      "Max sugar!"],
	"candy_cane":   ["Unlocked!",         "Longer sweep",      "Faster sweep",      "Bounces once",     "Max sugar!"],
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
	"ice_cream": 1, "toffee_bomb": 0, "rock_candy": 0,
	"lollipop": 0, "cotton_candy": 0, "candy_cane": 0,
}
var attr_levels: Dictionary = {
	"speed": 0, "damage": 0, "atk_spd": 0,
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

# Per-weapon fire timers (non ice-cream weapons)
var _wt: Dictionary = {"rock_candy": 0.0, "toffee_bomb": 0.0, "candy_cane": 0.0}
# Persistent weapon nodes
var _lollipop_orbs:     Array  = []
var _cotton_candy_aura: Node2D = null
var _lollipop_angle:    float  = 0.0

# Preloaded weapon scenes
const _ICE_CREAM_SCENE    := preload("res://scenes/weapons/ice_cream_shot/ice_cream_shot.tscn")
const _ROCK_CANDY_SCENE   := preload("res://scenes/weapons/rock_candy_shard/rock_candy_shard.tscn")
const _LOLLIPOP_SCENE     := preload("res://scenes/weapons/lollipop_orb/lollipop_orb.tscn")
const _COTTON_CANDY_SCENE := preload("res://scenes/weapons/cotton_candy_aura/cotton_candy_aura.tscn")
const _TOFFEE_BOMB_SCENE  := preload("res://scenes/weapons/toffee_bomb/toffee_bomb.tscn")
const _CANDY_CANE_SCENE   := preload("res://scenes/weapons/candy_cane_sweep/candy_cane_sweep.tscn")

@onready var animated_sprite = $AnimatedSprite2D

func _ready():
	add_to_group("player")
	current_hp = max_hp
	collision_layer = 1
	collision_mask = 2
	_register_movement_actions()
	_apply_weapon_effects()
	# Front-facing character: no mirror flip
	animated_sprite.flip_h = false
	animated_sprite.speed_scale = 1.0
	animated_sprite.play("idle")

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
	position = position.round()

	if direction != Vector2.ZERO:
		animated_sprite.speed_scale = 1.0
		if animated_sprite.animation != "walk":
			animated_sprite.play("walk")
	else:
		if animated_sprite.animation != "idle":
			animated_sprite.play("idle")

	shoot_timer -= delta
	if shoot_timer <= 0:
		shoot_timer = shoot_interval
		shoot()

	_tick_weapons(delta)
	_update_lollipop_orbs(delta)

func shoot():
	var aim := get_global_mouse_position() - global_position
	if aim.length_squared() < 1.0:
		aim = Vector2.RIGHT
	aim = aim.normalized()

	var sb_lv:    int   = weapon_levels.get("ice_cream", 1)
	var ball_count      := 1 if sb_lv < 3 else (2 if sb_lv < 5 else 3)
	var ball_speed: float = 300.0 + (sb_lv - 1) * 20.0
	var spread     := deg_to_rad(14.0)

	var offsets: Array = [0.0]
	if ball_count == 2:
		offsets = [-spread * 0.5, spread * 0.5]
	elif ball_count == 3:
		offsets = [-spread, 0.0, spread]

	for angle_offset in offsets:
		var shot = _ICE_CREAM_SCENE.instantiate()
		shot.global_position = global_position
		shot.direction        = aim.rotated(angle_offset)
		shot.speed            = ball_speed
		get_tree().current_scene.add_child(shot)

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
	var candidates: Array = []
	var weights:    Array = []

	for key in WEAPON_ORDER:
		var lv: int = weapon_levels.get(key, 0)
		if lv >= 6:
			continue
		candidates.append(_make_option(key, "weapon", lv))
		weights.append(2.0 if lv >= 1 else 1.0)

	for key in ATTR_ORDER:
		var lv: int = attr_levels.get(key, 0)
		if lv >= 6:
			continue
		candidates.append(_make_option(key, "attr", lv))
		weights.append(2.0 if lv >= 1 else 1.0)

	var chosen:   Array = []
	var pool:     Array = candidates.duplicate(true)
	var pw:       Array = weights.duplicate()

	for _i in range(mini(3, pool.size())):
		if pool.is_empty():
			break
		var total: float = 0.0
		for w in pw:
			total += w
		var roll: float = randf() * total
		var cum:  float = 0.0
		var idx:  int   = 0
		for j in range(pool.size()):
			cum += pw[j]
			if roll <= cum:
				idx = j
				break
		chosen.append(pool[idx])
		pool.remove_at(idx)
		pw.remove_at(idx)

	return chosen

func _make_option(key: String, kind: String, current_lv: int) -> Dictionary:
	var info = WEAPON_INFO[key] if kind == "weapon" else ATTR_INFO[key]
	var col: int = WEAPON_ORDER.find(key) if kind == "weapon" else ATTR_ORDER.find(key)

	var desc: String
	if current_lv == 0:
		var what_dict: Dictionary = _WEAPON_WHAT if kind == "weapon" else _ATTR_WHAT
		desc = what_dict.get(key, "")
	else:
		var descs: Array = _UPGRADE_DESC.get(key, [])
		var desc_idx: int = clamp(current_lv - 1, 0, descs.size() - 1)
		desc = descs[desc_idx] if descs.size() > 0 else ""

	return {
		"id":         key,
		"type":       kind,
		"name":       info["name"],
		"icon":       info["icon"],
		"color":      info["color"],
		"current_lv": current_lv,
		"desc":       desc,
		"col":   col,
		"row":   0 if kind == "weapon" else 1,
	}

func apply_upgrade(upgrade_id: String) -> void:
	if upgrade_id in weapon_levels:
		weapon_levels[upgrade_id] = min(6, max(1, weapon_levels[upgrade_id] + 1))
	elif upgrade_id in attr_levels:
		attr_levels[upgrade_id] = min(6, max(1, attr_levels[upgrade_id] + 1))
	_apply_weapon_effects()
	weapons_changed.emit(weapon_levels, attr_levels)
	_levelup_busy = false
	_show_next_levelup()

func _apply_weapon_effects() -> void:
	var sb_lv:  int = weapon_levels.get("ice_cream", 1)
	var spd_lv: int = attr_levels.get("speed", 0)
	shoot_interval = max(0.4, _BASE_INTERVAL - (sb_lv - 1) * 0.06)
	shoot_timer    = min(shoot_timer, shoot_interval)
	speed = _BASE_SPEED + spd_lv * 16.0
	_update_lollipop(weapon_levels.get("lollipop", 0))
	_update_cotton_candy(weapon_levels.get("cotton_candy", 0))

func _on_player_died():
	_dead = true
	player_died.emit()

# Same frame as move + position.round() — avoids _process vs physics desync jitter
func _update_lollipop_orbs(delta: float) -> void:
	if _lollipop_orbs.is_empty():
		return
	_lollipop_angle += delta * 1.8
	for orb in _lollipop_orbs:
		if is_instance_valid(orb):
			var r: float   = orb.get_meta("radius")
			var off: float = orb.get_meta("offset")
			var a: float   = _lollipop_angle + off
			orb.position   = (Vector2(cos(a), sin(a)) * r).round()

# ── Other weapon ticks ────────────────────────────────────────────────────────
func _tick_weapons(delta: float) -> void:
	var rc_lv: int = weapon_levels.get("rock_candy", 0)
	if rc_lv >= 1:
		_wt["rock_candy"] -= delta
		if _wt["rock_candy"] <= 0:
			_wt["rock_candy"] = max(0.6, 2.5 - (rc_lv - 1) * 0.35)
			_shoot_rock_candy()

	var tb_lv: int = weapon_levels.get("toffee_bomb", 0)
	if tb_lv >= 1:
		_wt["toffee_bomb"] -= delta
		if _wt["toffee_bomb"] <= 0:
			_wt["toffee_bomb"] = max(0.8, 3.5 - (tb_lv - 1) * 0.5)
			_drop_toffee_bomb()

	var cca_lv: int = weapon_levels.get("candy_cane", 0)
	if cca_lv >= 1:
		_wt["candy_cane"] -= delta
		if _wt["candy_cane"] <= 0:
			_wt["candy_cane"] = max(0.5, 2.0 - (cca_lv - 1) * 0.25)
			_sweep_candy_cane()

# ── Rock Candy ────────────────────────────────────────────────────────────────
func _shoot_rock_candy() -> void:
	var rc_lv: int   = weapon_levels.get("rock_candy", 1)
	var count: int   = 6 + (rc_lv - 1) * 2
	var spd:   float = 260.0 + (rc_lv - 1) * 20.0
	for i in range(count):
		var angle: float = TAU * i / count
		var shard        = _ROCK_CANDY_SCENE.instantiate()
		shard.global_position = global_position
		shard.direction       = Vector2(cos(angle), sin(angle))
		shard.speed           = spd
		get_tree().current_scene.add_child(shard)

# ── Toffee Bomb ───────────────────────────────────────────────────────────────
func _drop_toffee_bomb() -> void:
	var tb_lv: int    = weapon_levels.get("toffee_bomb", 1)
	var radius: float = 80.0 + (tb_lv - 1) * 18.0
	var target: Vector2 = global_position + Vector2(randf_range(-180, 180), randf_range(-180, 180))
	var nearest = _find_nearest_enemy(380.0)
	if nearest:
		target = nearest.global_position
	var bomb = _TOFFEE_BOMB_SCENE.instantiate()
	bomb.explosion_radius = radius
	bomb.fuse_time = 1.2 - (tb_lv - 1) * 0.05
	bomb.global_position = target
	get_tree().current_scene.add_child(bomb)

# ── Candy Cane Sweep ──────────────────────────────────────────────────────────
func _sweep_candy_cane() -> void:
	var cca_lv: int   = weapon_levels.get("candy_cane", 1)
	var radius: float = 90.0 + (cca_lv - 1) * 18.0
	var sweep = _CANDY_CANE_SCENE.instantiate()
	sweep.sweep_radius    = radius
	sweep.global_position = global_position
	get_tree().current_scene.add_child(sweep)

# ── Lollipop Orbs ─────────────────────────────────────────────────────────────
func _update_lollipop(new_lv: int) -> void:
	for orb in _lollipop_orbs:
		if is_instance_valid(orb): orb.queue_free()
	_lollipop_orbs.clear()
	if new_lv <= 0:
		return
	var orb_count: int  = 1 + (new_lv - 1) / 2
	var orbit_r:   float = 6.0 + (new_lv - 1) * 0.5
	for i in range(orb_count):
		var orb = _LOLLIPOP_SCENE.instantiate()
		orb.set_meta("radius", orbit_r)
		orb.set_meta("offset", TAU * i / orb_count)
		add_child(orb)
		_lollipop_orbs.append(orb)

# ── Cotton Candy Aura ─────────────────────────────────────────────────────────
func _update_cotton_candy(new_lv: int) -> void:
	if is_instance_valid(_cotton_candy_aura): _cotton_candy_aura.queue_free()
	_cotton_candy_aura = null
	if new_lv <= 0:
		return
	var aura_r:   float = 2.2 + (new_lv - 1) * 0.35
	var interval: float = max(0.4, 1.5 - (new_lv - 1) * 0.2)
	var aura = _COTTON_CANDY_SCENE.instantiate()
	aura.aura_radius   = aura_r
	aura.tick_interval = interval
	add_child(aura)
	_cotton_candy_aura = aura

# ── Helpers ───────────────────────────────────────────────────────────────────
func _find_nearest_enemy(max_dist: float):
	var closest = null
	var closest_dist: float = max_dist
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e): continue
		var d: float = global_position.distance_to(e.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = e
	return closest
