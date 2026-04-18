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

# What each weapon/attribute IS (shown when unlocking at lv 0 → 1) — base stats before other passives
const _WEAPON_WHAT: Dictionary = {
	"ice_cream":    "Primary shot: 1 cone, 0.80s cooldown, 300 speed, 3s flight (modified by ATK SPD / DURATION).",
	"toffee_bomb":  "Every ~3.5s drops a bomb (homing if a foe is near): 80px kill radius, 1.20s fuse (AREA / DURATION / ATK SPD apply).",
	"rock_candy":   "Every ~2.5s: ring of 6 shards, 260 speed, 3s lifetime (AREA / DURATION / ATK SPD apply).",
	"lollipop":     "Orbiting hit orbs: starts with 1 orb, ~6px orbit radius (more orbs & wider orbit per level).",
	"cotton_candy": "Damage aura: ~2.2 radius (player scale), tick ~1.5s (AREA scales radius; ATK SPD speeds ticks).",
	"candy_cane":   "Every ~2.0s: spinning sweep, 90px radius (AREA widens; ATK SPD speeds swings).",
}
const _ATTR_WHAT: Dictionary = {
	"speed":    "Move speed +16 (base 320 → 336 px/s; stacks +16 per level).",
	"damage":   "Damage multiplier +10% per level (×1.1, ×1.2…). Helps weapons chew through tougher enemies faster.",
	"atk_spd":  "All weapon cooldowns ×0.95 per level (stacks multiplicatively).",
	"area":     "Explosion, sweep & cotton aura radius +15% per level (multiplicative).",
	"duration": "Projectile lifetime & bomb fuse +20% per level (multiplicative).",
	"magnet":   "Gem attraction radius +20 px per level (base 90 px).",
}

const _BASE_SPEED    := 360.0
const _BASE_INTERVAL := 0.8
const _PLAYER_REF_SCALE := 14.0
const _ICE_CREAM_DAMAGE := 12.0
const _ROCK_CANDY_DAMAGE := 8.0
const _TOFFEE_BOMB_DAMAGE := 24.0
const _LOLLIPOP_DAMAGE := 10.0
const _COTTON_CANDY_DAMAGE := 8.0
const _CANDY_CANE_DAMAGE := 18.0

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
var _magnet_pulse_time: float = 0.0

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

	if _magnet_pulse_time > 0.0:
		_magnet_pulse_time = maxf(0.0, _magnet_pulse_time - delta)

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

func _process(delta: float) -> void:
	if _dead:
		return
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

	var life: float = 3.0 * _stat_dur_mult()
	var damage: float = _weapon_damage(_ICE_CREAM_DAMAGE + float(sb_lv - 1) * 2.0)
	for angle_offset in offsets:
		var shot = _ICE_CREAM_SCENE.instantiate()
		shot.global_position = global_position
		shot.direction        = aim.rotated(angle_offset)
		shot.speed            = ball_speed
		shot.lifetime         = life
		shot.damage           = damage
		get_tree().current_scene.add_child(shot)

func get_effective_gem_attract_radius() -> float:
	return gem_attract_radius + (720.0 if _magnet_pulse_time > 0.0 else 0.0)


func apply_magnet_pulse(duration_sec: float) -> void:
	if _dead or duration_sec <= 0.0:
		return
	_magnet_pulse_time = maxf(_magnet_pulse_time, duration_sec)


func heal(amount: int) -> void:
	if _dead or amount <= 0:
		return
	current_hp = mini(max_hp, current_hp + amount)
	stats_changed.emit(current_hp, max_hp, current_xp, xp_to_next_level, level)


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

func _fmt_f(x: float, decimals: int = 2) -> String:
	var q: float = pow(10.0, float(decimals))
	return str(snappedf(x * q, 1.0) / q)

func _stat_asp_mult() -> float:
	return pow(0.95, float(attr_levels.get("atk_spd", 0)))

func _stat_dur_mult() -> float:
	return 1.0 + 0.2 * float(attr_levels.get("duration", 0))

func _stat_area_mult() -> float:
	return 1.0 + 0.15 * float(attr_levels.get("area", 0))

func _stat_damage_mult() -> float:
	return 1.0 + 0.1 * float(attr_levels.get("damage", 0))

func _weapon_damage(base_damage: float) -> float:
	return base_damage * _stat_damage_mult()

func _upgrade_choice_desc(key: String, cur_lv: int) -> String:
	var asp: float = _stat_asp_mult()
	var dur: float = _stat_dur_mult()
	var area: float = _stat_area_mult()
	var sm: float = scale.x / _PLAYER_REF_SCALE
	var fr: float = float(cur_lv)
	match key:
		"ice_cream":
			var bi: float = max(0.4, _BASE_INTERVAL - (fr - 1.0) * 0.06) * asp
			var ai: float = max(0.4, _BASE_INTERVAL - fr * 0.06) * asp
			var bspd: float = 300.0 + (fr - 1.0) * 20.0
			var aspd: float = 300.0 + fr * 20.0
			var bc: int = 1 if cur_lv < 3 else (2 if cur_lv < 5 else 3)
			var ac: int = 1 if cur_lv + 1 < 3 else (2 if cur_lv + 1 < 5 else 3)
			var lines: PackedStringArray = PackedStringArray()
			lines.append("Shot interval " + _fmt_f(bi) + "s → " + _fmt_f(ai) + "s (" + _fmt_f(ai - bi) + "s)")
			lines.append("Cone speed " + _fmt_f(bspd, 0) + " → " + _fmt_f(aspd, 0))
			if ac > bc:
				lines.append("Cones per shot: " + str(bc) + " → " + str(ac))
			lines.append("Flight time " + _fmt_f(3.0 * dur) + "s (duration mult)")
			return "\n".join(lines)
		"rock_candy":
			var bcd: float = max(0.6, 2.5 - (fr - 1.0) * 0.35) * asp
			var acd: float = max(0.6, 2.5 - fr * 0.35) * asp
			var bn: int = int(6.0 + (fr - 1.0) * 2.0)
			var an: int = int(6.0 + fr * 2.0)
			var bspd: float = 260.0 + (fr - 1.0) * 20.0
			var aspd: float = 260.0 + fr * 20.0
			var lines2: PackedStringArray = PackedStringArray()
			lines2.append("Volley every " + _fmt_f(bcd) + "s → " + _fmt_f(acd) + "s")
			lines2.append("Shards " + str(bn) + " → " + str(an) + ", speed " + _fmt_f(bspd, 0) + " → " + _fmt_f(aspd, 0))
			lines2.append("Shard lifetime " + _fmt_f(3.0 * dur) + "s")
			return "\n".join(lines2)
		"toffee_bomb":
			var brad: float = (80.0 + (fr - 1.0) * 18.0) * area
			var arad: float = (80.0 + fr * 18.0) * area
			var bf: float = max(0.15, (1.2 - (fr - 1.0) * 0.05) * dur)
			var af: float = max(0.15, (1.2 - fr * 0.05) * dur)
			var bdrop: float = max(0.8, 3.5 - (fr - 1.0) * 0.5) * asp
			var adrop: float = max(0.8, 3.5 - fr * 0.5) * asp
			var lines3: PackedStringArray = PackedStringArray()
			lines3.append("Blast radius " + _fmt_f(brad, 0) + " → " + _fmt_f(arad, 0) + " px")
			lines3.append("Fuse " + _fmt_f(bf) + "s → " + _fmt_f(af) + "s")
			lines3.append("Drop every " + _fmt_f(bdrop) + "s → " + _fmt_f(adrop) + "s")
			return "\n".join(lines3)
		"lollipop":
			var bo: int = 1 + (cur_lv - 1) / 2
			var ao: int = 1 + cur_lv / 2
			var br: float = (6.0 + (fr - 1.0) * 0.5) * area
			var ar: float = (6.0 + fr * 0.5) * area
			var lines4: PackedStringArray = PackedStringArray()
			if ao > bo:
				lines4.append("Orbs: " + str(bo) + " → " + str(ao))
			lines4.append("Orbit radius " + _fmt_f(br) + " → " + _fmt_f(ar) + " (× area)")
			return "\n".join(lines4)
		"cotton_candy":
			var br: float = (2.2 + (fr - 1.0) * 0.35) * sm * area
			var ar: float = (2.2 + fr * 0.35) * sm * area
			var bt: float = max(0.4, 1.5 - (fr - 1.0) * 0.2) * asp
			var at: float = max(0.4, 1.5 - fr * 0.2) * asp
			var lines5: PackedStringArray = PackedStringArray()
			lines5.append("Aura radius " + _fmt_f(br) + " → " + _fmt_f(ar))
			lines5.append("Damage tick " + _fmt_f(bt) + "s → " + _fmt_f(at) + "s")
			return "\n".join(lines5)
		"candy_cane":
			var br: float = (90.0 + (fr - 1.0) * 18.0) * area
			var ar: float = (90.0 + fr * 18.0) * area
			var bsw: float = max(0.5, 2.0 - (fr - 1.0) * 0.25) * asp
			var asw: float = max(0.5, 2.0 - fr * 0.25) * asp
			var lines6: PackedStringArray = PackedStringArray()
			lines6.append("Sweep radius " + _fmt_f(br, 0) + " → " + _fmt_f(ar, 0) + " px")
			lines6.append("Swing every " + _fmt_f(bsw) + "s → " + _fmt_f(asw) + "s")
			return "\n".join(lines6)
		"speed":
			var bmv: float = _BASE_SPEED + fr * 16.0
			var amv: float = _BASE_SPEED + (fr + 1.0) * 16.0
			return "Move speed " + _fmt_f(bmv, 0) + " → " + _fmt_f(amv, 0) + " px/s (+16)"
		"damage":
			var bm: float = 1.0 + fr * 0.1
			var am: float = 1.0 + (fr + 1.0) * 0.1
			return "Damage mult ×" + _fmt_f(bm, 1) + " → ×" + _fmt_f(am, 1) + "\n(All weapon hits scale with this.)"
		"atk_spd":
			var basp: float = pow(0.95, fr)
			var aasp: float = pow(0.95, fr + 1.0)
			return "Cooldown ×" + _fmt_f(basp, 3) + " → ×" + _fmt_f(aasp, 3) + "\n(~5% faster per level, stacks)"
		"area":
			var bam: float = 1.0 + fr * 0.15
			var aam: float = 1.0 + (fr + 1.0) * 0.15
			return "Size ×" + _fmt_f(bam, 2) + " → ×" + _fmt_f(aam, 2) + "\n(bomb, sweep, cotton, lollipop orbit)"
		"duration":
			var bdm: float = 1.0 + fr * 0.2
			var adm: float = 1.0 + (fr + 1.0) * 0.2
			return "Duration ×" + _fmt_f(bdm, 2) + " → ×" + _fmt_f(adm, 2) + "\n(ice & rock flight, bomb fuse)"
		"magnet":
			var brp: float = 90.0 + fr * 20.0
			var arp: float = 90.0 + (fr + 1.0) * 20.0
			return "Gem attract radius " + _fmt_f(brp, 0) + " → " + _fmt_f(arp, 0) + " px (+20)"
		_:
			return ""

func _make_option(key: String, kind: String, current_lv: int) -> Dictionary:
	var info = WEAPON_INFO[key] if kind == "weapon" else ATTR_INFO[key]
	var col: int = WEAPON_ORDER.find(key) if kind == "weapon" else ATTR_ORDER.find(key)

	var desc: String
	if current_lv == 0:
		var what_dict: Dictionary = _WEAPON_WHAT if kind == "weapon" else _ATTR_WHAT
		desc = what_dict.get(key, "")
	else:
		desc = _upgrade_choice_desc(key, current_lv)

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
	var asp: float = _stat_asp_mult()
	shoot_interval = max(0.4, _BASE_INTERVAL - float(sb_lv - 1) * 0.06) * asp
	shoot_timer    = min(shoot_timer, shoot_interval)
	speed = _BASE_SPEED + float(spd_lv) * 16.0
	gem_attract_radius = 90.0 + float(attr_levels.get("magnet", 0)) * 20.0
	_update_lollipop(weapon_levels.get("lollipop", 0))
	_update_cotton_candy(weapon_levels.get("cotton_candy", 0))

func _on_player_died():
	_dead = true
	player_died.emit()

# _process + sub-pixel local pos: avoids orbit jitter from .round() on a rotating vector
func _update_lollipop_orbs(delta: float) -> void:
	if _lollipop_orbs.is_empty():
		return
	_lollipop_angle += delta * 1.8
	for orb in _lollipop_orbs:
		if is_instance_valid(orb):
			var r: float   = orb.get_meta("radius")
			var off: float = orb.get_meta("offset")
			var a: float   = _lollipop_angle + off
			orb.position   = Vector2(cos(a), sin(a)) * r

# ── Other weapon ticks ────────────────────────────────────────────────────────
func _tick_weapons(delta: float) -> void:
	var rc_lv: int = weapon_levels.get("rock_candy", 0)
	if rc_lv >= 1:
		_wt["rock_candy"] -= delta
		if _wt["rock_candy"] <= 0:
			_wt["rock_candy"] = max(0.6, 2.5 - (rc_lv - 1) * 0.35) * _stat_asp_mult()
			_shoot_rock_candy()

	var tb_lv: int = weapon_levels.get("toffee_bomb", 0)
	if tb_lv >= 1:
		_wt["toffee_bomb"] -= delta
		if _wt["toffee_bomb"] <= 0:
			_wt["toffee_bomb"] = max(0.8, 3.5 - (tb_lv - 1) * 0.5) * _stat_asp_mult()
			_drop_toffee_bomb()

	var cca_lv: int = weapon_levels.get("candy_cane", 0)
	if cca_lv >= 1:
		_wt["candy_cane"] -= delta
		if _wt["candy_cane"] <= 0:
			_wt["candy_cane"] = max(0.5, 2.0 - (cca_lv - 1) * 0.25) * _stat_asp_mult()
			_sweep_candy_cane()

# ── Rock Candy ────────────────────────────────────────────────────────────────
func _shoot_rock_candy() -> void:
	var rc_lv: int   = weapon_levels.get("rock_candy", 1)
	var count: int   = 6 + (rc_lv - 1) * 2
	var spd:   float = 260.0 + (rc_lv - 1) * 20.0
	var damage: float = _weapon_damage(_ROCK_CANDY_DAMAGE + float(rc_lv - 1) * 1.5)
	for i in range(count):
		var angle: float = TAU * i / count
		var shard        = _ROCK_CANDY_SCENE.instantiate()
		shard.global_position = global_position
		shard.direction       = Vector2(cos(angle), sin(angle))
		shard.speed           = spd
		shard.lifetime        = 3.0 * _stat_dur_mult()
		shard.damage          = damage
		get_tree().current_scene.add_child(shard)

# ── Toffee Bomb ───────────────────────────────────────────────────────────────
func _drop_toffee_bomb() -> void:
	var tb_lv: int    = weapon_levels.get("toffee_bomb", 1)
	var radius: float = 80.0 + (tb_lv - 1) * 18.0
	var damage: float = _weapon_damage(_TOFFEE_BOMB_DAMAGE + float(tb_lv - 1) * 4.0)
	var target: Vector2 = global_position + Vector2(randf_range(-180, 180), randf_range(-180, 180))
	var nearest = _find_nearest_enemy(380.0)
	if nearest:
		target = nearest.global_position
	var bomb = _TOFFEE_BOMB_SCENE.instantiate()
	bomb.explosion_radius = radius * _stat_area_mult()
	bomb.fuse_time = max(0.15, (1.2 - (tb_lv - 1) * 0.05) * _stat_dur_mult())
	bomb.damage = damage
	bomb.global_position = target
	get_tree().current_scene.add_child(bomb)

# ── Candy Cane Sweep ──────────────────────────────────────────────────────────
func _sweep_candy_cane() -> void:
	var cca_lv: int   = weapon_levels.get("candy_cane", 1)
	var radius: float = 90.0 + (cca_lv - 1) * 18.0
	var damage: float = _weapon_damage(_CANDY_CANE_DAMAGE + float(cca_lv - 1) * 3.0)
	var sweep = _CANDY_CANE_SCENE.instantiate()
	sweep.sweep_radius    = radius * _stat_area_mult()
	sweep.damage          = damage
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
	var orbit_r:   float = (6.0 + (new_lv - 1) * 0.5) * _stat_area_mult()
	var damage: float = _weapon_damage(_LOLLIPOP_DAMAGE + float(new_lv - 1) * 2.0)
	for i in range(orb_count):
		var orb = _LOLLIPOP_SCENE.instantiate()
		orb.set_meta("radius", orbit_r)
		orb.set_meta("offset", TAU * i / orb_count)
		orb.damage = damage
		add_child(orb)
		_lollipop_orbs.append(orb)

# ── Cotton Candy Aura ─────────────────────────────────────────────────────────
func _update_cotton_candy(new_lv: int) -> void:
	if is_instance_valid(_cotton_candy_aura): _cotton_candy_aura.queue_free()
	_cotton_candy_aura = null
	if new_lv <= 0:
		return
	var sm: float      = scale.x / _PLAYER_REF_SCALE
	var aura_r: float  = (2.2 + (new_lv - 1) * 0.35) * sm * _stat_area_mult()
	var interval: float = max(0.4, 1.5 - (new_lv - 1) * 0.2) * _stat_asp_mult()
	var damage: float = _weapon_damage(_COTTON_CANDY_DAMAGE + float(new_lv - 1) * 2.0)
	var aura = _COTTON_CANDY_SCENE.instantiate()
	aura.aura_radius   = aura_r
	aura.tick_interval = interval
	aura.damage        = damage
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
