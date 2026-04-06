extends CanvasLayer

var _hp_bar: ProgressBar
var _xp_bar: ProgressBar
var _hp_num_label: Label
var _level_label: Label
var _timer_label: Label
var _go_overlay: Panel
var _go_time_label: Label
var _damage_flash: ColorRect

var _elapsed_time: float = 0.0
var _game_over: bool = false

# Weapon grid state
var _w_cells: Array = []   # 6 weapon cells  (row 0)
var _a_cells: Array = []   # 6 attr cells    (row 1)

# Level-up modal
var _levelup_overlay: Control = null
var _levelup_callback: Callable

# Individual icon textures, keyed by weapon/attr id
var _textures: Dictionary = {}

# ── Layout constants ───────────────────────────────────────────────────────────
const BORDER     = 3
const STRIP_H    = 38
const LVL_W      = 80
const HP_W  = 38
const HP_STRIP_W = 224
const HP_PAD     = 14
const TIMER_H    = 26
const TIMER_GAP  = 4
const MODAL_W    = 480
const MODAL_H    = 280

# Weapon grid
const CELL_W   = 64
const CELL_H   = 62
const CELL_GAP = 2
const ROW_GAP  = 3
const GRID_PAD = 8

const WEAPON_KEYS: Array = ["ice_cream", "toffee_bomb", "rock_candy", "lollipop", "cotton_candy", "candy_cane"]
const ATTR_KEYS:   Array = ["speed", "damage", "atk_spd", "area", "duration", "magnet"]

const W_INFO: Array = [
	{"icon": "◉",  "color": Color(0.98, 0.76, 0.62), "name": "ICE CREAM"},
	{"icon": "◈",  "color": Color(0.90, 0.62, 0.10), "name": "TOFFEE BOMB"},
	{"icon": "◆",  "color": Color(0.42, 0.72, 1.00), "name": "ROCK CANDY"},
	{"icon": "⊙",  "color": Color(0.98, 0.25, 0.72), "name": "LOLLIPOP"},
	{"icon": "☁",  "color": Color(0.98, 0.72, 0.88), "name": "COTTON CANDY"},
	{"icon": "∩",  "color": Color(0.95, 0.18, 0.18), "name": "CANDY CANE"},
]
const A_INFO: Array = [
	{"icon": "▶▶", "color": Color(0.98, 0.76, 0.62), "name": "SPEED"},
	{"icon": "⚔",  "color": Color(0.90, 0.62, 0.10), "name": "DAMAGE"},
	{"icon": "↺",  "color": Color(0.42, 0.72, 1.00), "name": "ATK SPD"},
	{"icon": "◎",  "color": Color(0.98, 0.25, 0.72), "name": "AREA"},
	{"icon": "⏱",  "color": Color(0.98, 0.72, 0.88), "name": "DURATION"},
	{"icon": "⊕",  "color": Color(0.95, 0.18, 0.18), "name": "MAGNET"},
]

# ── Palette ────────────────────────────────────────────────────────────────────
const C_XP_BG    = Color(0.05, 0.04, 0.18)
const C_XP_FILL  = Color(0.08, 0.72, 1.00)
const C_XP_BDR   = Color(0.10, 0.25, 0.58)
const C_LVL_BG   = Color(0.12, 0.06, 0.28)
const C_LVL_BDR  = Color(0.52, 0.30, 0.94)

const C_HP_STRIP  = Color(0.06, 0.02, 0.02)
const C_HP_BDR    = Color(0.62, 0.08, 0.08)
const C_HEART_BG  = Color(0.24, 0.05, 0.05)
const C_HP_BAR_BG = Color(0.14, 0.03, 0.03)
const C_HP_FILL   = Color(0.96, 0.12, 0.10)

const C_LOCKED_BG   = Color(0.20, 0.20, 0.23, 0.88)
const C_LOCKED_BDR  = Color(0.30, 0.30, 0.36)
const C_LOCKED_TEXT = Color(0.42, 0.42, 0.48)
const C_CELL_BG     = Color(0.04, 0.05, 0.08, 0.92)

# ── Init ───────────────────────────────────────────────────────────────────────
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root = Control.new()
	root.name = "HUDRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_load_icons()
	_build_xp_strip(root)
	_build_weapon_grid(root)
	_build_timer_label(root)
	_build_hp_strip(root)
	_build_damage_flash(root)
	_build_game_over(root)
	_build_crosshair()

func _process(delta: float) -> void:
	if _game_over:
		return
	_elapsed_time += delta
	if _timer_label:
		_timer_label.text = _fmt_time(_elapsed_time)

# ── Icon textures ──────────────────────────────────────────────────────────────
func _load_icons() -> void:
	var all_keys: Array = WEAPON_KEYS + ATTR_KEYS
	for key in all_keys:
		var path := "res://assets/sprites/weapons/%s.png" % key
		if ResourceLoader.exists(path):
			_textures[key] = load(path)

# ── XP bar ─────────────────────────────────────────────────────────────────────
func _build_xp_strip(root: Control) -> void:
	var strip = Panel.new()
	strip.anchor_left   = 0.0
	strip.anchor_right  = 1.0
	strip.offset_bottom = STRIP_H
	strip.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	strip.add_theme_stylebox_override("panel", _pbox(C_XP_BG, C_XP_BDR))
	root.add_child(strip)

	var lvl_panel = Panel.new()
	lvl_panel.position = Vector2(0, 0)
	lvl_panel.size = Vector2(LVL_W, STRIP_H)
	lvl_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lvl_panel.add_theme_stylebox_override("panel", _pbox(C_LVL_BG, C_LVL_BDR))
	strip.add_child(lvl_panel)

	_level_label = Label.new()
	_level_label.position = Vector2(0, 0)
	_level_label.size = Vector2(LVL_W, STRIP_H)
	_level_label.text = "LVL  1"
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level_label.add_theme_font_size_override("font_size", 15)
	_level_label.add_theme_color_override("font_color", Color(0.90, 0.74, 1.00))
	_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lvl_panel.add_child(_level_label)

	_xp_bar = ProgressBar.new()
	_xp_bar.anchor_left   = 0.0
	_xp_bar.anchor_right  = 1.0
	_xp_bar.anchor_top    = 0.0
	_xp_bar.anchor_bottom = 1.0
	_xp_bar.offset_left   = LVL_W + BORDER
	_xp_bar.offset_right  = -BORDER
	_xp_bar.offset_top    = BORDER
	_xp_bar.offset_bottom = -BORDER
	_xp_bar.max_value = 100
	_xp_bar.value = 0
	_xp_bar.show_percentage = false
	_xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_bar(_xp_bar, C_XP_BG, C_XP_FILL)
	strip.add_child(_xp_bar)

# ── Timer bar ──────────────────────────────────────────────────────────────────
func _build_timer_label(root: Control) -> void:
	var panel = Panel.new()
	panel.anchor_left   = 0.0
	panel.anchor_right  = 0.0
	panel.anchor_top    = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left   = HP_PAD
	panel.offset_right  = HP_PAD + HP_STRIP_W
	panel.offset_top    = -(HP_PAD + STRIP_H + TIMER_GAP + TIMER_H)
	panel.offset_bottom = -(HP_PAD + STRIP_H + TIMER_GAP)
	panel.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.04, 0.03, 0.08, 0.88)
	s.border_color = Color(0.22, 0.18, 0.36)
	s.border_width_left = 2
	s.border_width_right = 2
	s.border_width_top = 2
	s.border_width_bottom = 2
	panel.add_theme_stylebox_override("panel", s)
	root.add_child(panel)

	_timer_label = Label.new()
	_timer_label.text = "0:00"
	_timer_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override("font_size", 13)
	_timer_label.add_theme_color_override("font_color", Color(0.82, 0.82, 1.00))
	_timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_timer_label)

# ── HP bar ─────────────────────────────────────────────────────────────────────
func _build_hp_strip(root: Control) -> void:
	var strip = Panel.new()
	strip.anchor_left   = 0.0
	strip.anchor_right  = 0.0
	strip.anchor_top    = 1.0
	strip.anchor_bottom = 1.0
	strip.offset_left   = HP_PAD
	strip.offset_right  = HP_PAD + HP_STRIP_W
	strip.offset_top    = -(HP_PAD + STRIP_H)
	strip.offset_bottom = -HP_PAD
	strip.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	strip.add_theme_stylebox_override("panel", _pbox(C_HP_STRIP, C_HP_BDR))
	root.add_child(strip)

	var heart_panel = Panel.new()
	heart_panel.position = Vector2(0, 0)
	heart_panel.size = Vector2(HP_W, STRIP_H)
	heart_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heart_panel.add_theme_stylebox_override("panel", _pbox(C_HEART_BG, C_HP_BDR))
	strip.add_child(heart_panel)

	var heart_lbl = Label.new()
	heart_lbl.text = "♥"
	heart_lbl.position = Vector2(0, 0)
	heart_lbl.size = Vector2(HP_W, STRIP_H)
	heart_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heart_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heart_lbl.add_theme_font_size_override("font_size", 18)
	heart_lbl.add_theme_color_override("font_color", Color(1.0, 0.38, 0.38))
	heart_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heart_panel.add_child(heart_lbl)

	_hp_bar = ProgressBar.new()
	_hp_bar.anchor_left   = 0.0
	_hp_bar.anchor_right  = 1.0
	_hp_bar.anchor_top    = 0.0
	_hp_bar.anchor_bottom = 1.0
	_hp_bar.offset_left   = HP_W + BORDER
	_hp_bar.offset_right  = -BORDER
	_hp_bar.offset_top    = BORDER
	_hp_bar.offset_bottom = -BORDER
	_hp_bar.max_value = 100
	_hp_bar.value = 100
	_hp_bar.show_percentage = false
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_bar(_hp_bar, C_HP_BAR_BG, C_HP_FILL)
	strip.add_child(_hp_bar)

	_hp_num_label = Label.new()
	_hp_num_label.text = "100"
	_hp_num_label.anchor_left   = 0.0
	_hp_num_label.anchor_right  = 1.0
	_hp_num_label.anchor_top    = 0.0
	_hp_num_label.anchor_bottom = 1.0
	_hp_num_label.offset_left   = HP_W
	_hp_num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_num_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_num_label.add_theme_font_size_override("font_size", 14)
	_hp_num_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_hp_num_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_hp_num_label.add_theme_constant_override("outline_size", 3)
	_hp_num_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(_hp_num_label)

# ── Damage flash ───────────────────────────────────────────────────────────────
func _build_damage_flash(root: Control) -> void:
	_damage_flash = ColorRect.new()
	_damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_flash.color = Color(1.0, 0.0, 0.0, 0.0)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_damage_flash)

# ── Game over overlay ──────────────────────────────────────────────────────────
func _build_game_over(root: Control) -> void:
	_go_overlay = Panel.new()
	_go_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_go_overlay.visible = false
	var ov_style = StyleBoxFlat.new()
	ov_style.bg_color = Color(0.0, 0.0, 0.0, 0.74)
	_go_overlay.add_theme_stylebox_override("panel", ov_style)
	root.add_child(_go_overlay)

	var modal = Panel.new()
	modal.anchor_left   = 0.5
	modal.anchor_right  = 0.5
	modal.anchor_top    = 0.5
	modal.anchor_bottom = 0.5
	modal.offset_left   = -MODAL_W / 2
	modal.offset_right  =  MODAL_W / 2
	modal.offset_top    = -MODAL_H / 2
	modal.offset_bottom =  MODAL_H / 2
	modal.add_theme_stylebox_override("panel", _pbox(Color(0.06, 0.02, 0.03), Color(0.80, 0.10, 0.10)))
	_go_overlay.add_child(modal)

	var title = Label.new()
	title.text = "GAME OVER"
	title.position = Vector2(0, 28)
	title.size = Vector2(MODAL_W, 58)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(1.0, 0.20, 0.16))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	title.add_theme_constant_override("outline_size", 3)
	modal.add_child(title)

	_go_time_label = Label.new()
	_go_time_label.text = "Survived  0:00"
	_go_time_label.position = Vector2(0, 105)
	_go_time_label.size = Vector2(MODAL_W, 32)
	_go_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_go_time_label.add_theme_font_size_override("font_size", 20)
	_go_time_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.78))
	modal.add_child(_go_time_label)

	var btn = Button.new()
	btn.text = "RESTART"
	btn.position = Vector2(MODAL_W / 2 - 85, 175)
	btn.size = Vector2(170, 48)
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color", Color(1.0, 1.0, 0.82))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.88, 0.60))
	btn.add_theme_stylebox_override("normal",  _pbox(Color(0.14, 0.06, 0.04), Color(0.70, 0.14, 0.10)))
	btn.add_theme_stylebox_override("hover",   _pbox(Color(0.32, 0.08, 0.06), Color(0.95, 0.22, 0.16)))
	btn.add_theme_stylebox_override("pressed", _pbox(Color(0.55, 0.08, 0.05), Color(0.95, 0.22, 0.16)))
	btn.add_theme_stylebox_override("focus",   _pbox(Color(0.14, 0.06, 0.04), Color(0.70, 0.14, 0.10)))
	btn.pressed.connect(_on_restart_pressed)
	modal.add_child(btn)

# ── Weapon grid (2 rows × 6 cols) ─────────────────────────────────────────────
func _build_weapon_grid(root: Control) -> void:
	_w_cells.clear()
	_a_cells.clear()
	var start_y := float(STRIP_H) + float(GRID_PAD)

	for i in range(6):
		var cx := float(GRID_PAD) + i * (CELL_W + CELL_GAP)
		_w_cells.append(_make_grid_cell(root, cx, start_y))
		_a_cells.append(_make_grid_cell(root, cx, start_y + CELL_H + ROW_GAP))

func _make_grid_cell(root: Control, x: float, y: float) -> Dictionary:
	var panel := Panel.new()
	panel.position = Vector2(x, y)
	panel.size = Vector2(CELL_W, CELL_H)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _pbox(C_LOCKED_BG, C_LOCKED_BDR, 1))
	root.add_child(panel)

	# TextureRect for sprite icons (hidden until a texture is assigned)
	var tex_rect := TextureRect.new()
	tex_rect.anchor_left   = 0.0
	tex_rect.anchor_right  = 1.0
	tex_rect.anchor_top    = 0.0
	tex_rect.anchor_bottom = 1.0
	tex_rect.offset_top    = 2
	tex_rect.offset_left   = 3
	tex_rect.offset_right  = -3
	tex_rect.offset_bottom = -14
	tex_rect.stretch_mode  = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.expand_mode   = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	tex_rect.visible       = false
	panel.add_child(tex_rect)

	# Label fallback (shown when no texture available)
	var lbl := Label.new()
	lbl.anchor_left   = 0.0
	lbl.anchor_right  = 1.0
	lbl.anchor_top    = 0.0
	lbl.anchor_bottom = 1.0
	lbl.offset_top    = 2
	lbl.offset_bottom = -14
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", C_LOCKED_TEXT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.text = ""
	panel.add_child(lbl)

	var lv_lbl := Label.new()
	lv_lbl.anchor_left   = 0.0
	lv_lbl.anchor_right  = 1.0
	lv_lbl.anchor_top    = 1.0
	lv_lbl.anchor_bottom = 1.0
	lv_lbl.offset_top    = -15
	lv_lbl.offset_bottom = -2
	lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_TOP
	lv_lbl.add_theme_font_size_override("font_size", 9)
	lv_lbl.add_theme_color_override("font_color", C_LOCKED_TEXT)
	lv_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lv_lbl.text = "---"
	panel.add_child(lv_lbl)

	return {"panel": panel, "tex_rect": tex_rect, "lbl": lbl, "lv_lbl": lv_lbl}

func update_weapons(weapon_levels: Dictionary, attr_levels: Dictionary) -> void:
	for i in range(6):
		_refresh_cell(_w_cells[i], weapon_levels.get(WEAPON_KEYS[i], 0), W_INFO[i], WEAPON_KEYS[i])
		_refresh_cell(_a_cells[i], attr_levels.get(ATTR_KEYS[i],   0), A_INFO[i], ATTR_KEYS[i])

func _refresh_cell(cell: Dictionary, lv: int, info: Dictionary, key: String) -> void:
	var tex: Texture2D = _textures.get(key, null)
	var has_tex := tex != null
	cell.tex_rect.visible  = has_tex
	cell.lbl.visible  = not has_tex

	if lv <= 0:
		cell.panel.add_theme_stylebox_override("panel", _pbox(C_LOCKED_BG, C_LOCKED_BDR, 1))
		cell.tex_rect.visible = false
		cell.lbl.visible = false
		cell.lv_lbl.text      = ""
	else:
		var c: Color = info["color"]
		var bg_c  := Color(c.r * 0.12, c.g * 0.12, c.b * 0.12, 0.94)
		var bdr_c := Color(c.r * 0.50, c.g * 0.50, c.b * 0.50)
		cell.panel.add_theme_stylebox_override("panel", _pbox(bg_c, bdr_c, 1))
		if has_tex:
			cell.tex_rect.texture  = tex
			cell.tex_rect.modulate = Color.WHITE
		else:
			cell.lbl.text = info["icon"]
			cell.lbl.add_theme_color_override("font_color", c)
		cell.lv_lbl.text   = "Lv %d" % lv
		cell.lv_lbl.add_theme_color_override("font_color", Color(c.r * 0.85, c.g * 0.85, c.b * 0.85))

# ── Level-up choice modal ──────────────────────────────────────────────────────
func show_level_up_choice(options: Array, on_chosen: Callable) -> void:
	_levelup_callback = on_chosen
	get_tree().paused = true
	_build_levelup_modal(options)

func _build_levelup_modal(options: Array) -> void:
	if _levelup_overlay:
		_levelup_overlay.queue_free()

	var root: Control = get_child(0)

	_levelup_overlay = Control.new()
	_levelup_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_levelup_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_levelup_overlay)

	# Dark backdrop
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.72)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_levelup_overlay.add_child(backdrop)

	# Title
	var title := Label.new()
	title.text = "LEVEL  UP!"
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.offset_top = 72
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment   = VERTICAL_ALIGNMENT_TOP
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.28))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	title.add_theme_constant_override("outline_size", 4)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_levelup_overlay.add_child(title)

	# Sub-title hint
	var hint := Label.new()
	hint.text = "Choose an upgrade"
	hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	hint.offset_top = 122
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment   = VERTICAL_ALIGNMENT_TOP
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.72, 0.72, 0.80))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_levelup_overlay.add_child(hint)

	# Cards
	const CARD_W   := 152.0
	const CARD_H   := 212.0
	const CARD_GAP := 18.0
	var n := options.size()
	if n == 0:
		return
	var vp    := get_viewport().get_visible_rect().size
	var total := n * CARD_W + (n - 1) * CARD_GAP
	var sx    := (vp.x - total) * 0.5
	var sy    := (vp.y - CARD_H) * 0.5 + 16.0

	for i in range(n):
		_build_card(_levelup_overlay, options[i], sx + i * (CARD_W + CARD_GAP), sy, CARD_W, CARD_H)

func _build_card(parent: Control, opt: Dictionary, x: float, y: float, w: float, h: float) -> void:
	var c: Color   = opt.get("color", Color.WHITE)
	var bg_c       := Color(c.r * 0.10, c.g * 0.10, c.b * 0.10, 0.96)
	var bdr_c      := Color(c.r * 0.55, c.g * 0.55, c.b * 0.55)
	var hover_bg_c := Color(c.r * 0.22, c.g * 0.22, c.b * 0.22, 0.98)

	var card := Button.new()
	card.position = Vector2(x, y)
	card.size     = Vector2(w, h)
	card.add_theme_stylebox_override("normal",  _pbox(bg_c, bdr_c))
	card.add_theme_stylebox_override("hover",   _pbox(hover_bg_c, c))
	card.add_theme_stylebox_override("pressed", _pbox(hover_bg_c, c))
	card.add_theme_stylebox_override("focus",   _pbox(bg_c, bdr_c))
	var up_id: String = opt.get("id", "")
	card.pressed.connect(func(): _on_upgrade_chosen(up_id))
	parent.add_child(card)

	# Type badge: WEAPON / ATTRIBUTE
	var kind: String    = opt.get("type", "weapon")
	var badge_text      := "WEAPON" if kind == "weapon" else "ATTRIBUTE"
	var badge_lbl       := Label.new()
	badge_lbl.text      = badge_text
	badge_lbl.position  = Vector2(0, 6)
	badge_lbl.size      = Vector2(w, 14)
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.add_theme_font_size_override("font_size", 8)
	badge_lbl.add_theme_color_override("font_color", Color(c.r * 0.75, c.g * 0.75, c.b * 0.75, 0.85))
	badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(badge_lbl)

	# Icon — sprite if loaded, unicode label otherwise
	var card_tex: Texture2D = _textures.get(opt.get("id", ""), null)
	if card_tex:
		var tex_rect := TextureRect.new()
		tex_rect.texture      = card_tex
		tex_rect.position     = Vector2(w * 0.5 - 28.0, 18.0)
		tex_rect.size         = Vector2(56.0, 56.0)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(tex_rect)
	else:
		var lbl := Label.new()
		lbl.text = opt.get("icon", "?")
		lbl.position = Vector2(0, 18)
		lbl.size     = Vector2(w, 52)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 30)
		lbl.add_theme_color_override("font_color", c)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(lbl)

	# Weapon/attr name
	var name_lbl := Label.new()
	name_lbl.text = opt.get("name", "???")
	name_lbl.position = Vector2(0, 80)
	name_lbl.size     = Vector2(w, 20)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", c)
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	name_lbl.add_theme_constant_override("outline_size", 2)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_lbl)

	# Level: "NEW!" for first unlock, "Lv X → X+1" for upgrades
	var cur: int    = opt.get("current_lv", 0)
	var lv_lbl      := Label.new()
	if cur == 0:
		lv_lbl.text = "NEW!"
		lv_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.18))
		lv_lbl.add_theme_font_size_override("font_size", 15)
	else:
		lv_lbl.text = "Lv %d  →  %d" % [cur, cur + 1]
		lv_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.55))
		lv_lbl.add_theme_font_size_override("font_size", 12)
	lv_lbl.position = Vector2(0, 102)
	lv_lbl.size     = Vector2(w, 22)
	lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(lv_lbl)

	# Description
	var desc_lbl := Label.new()
	desc_lbl.text = opt.get("desc", "")
	desc_lbl.position = Vector2(8, 128)
	desc_lbl.size     = Vector2(w - 16, 72)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", Color(0.80, 0.80, 0.84))
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(desc_lbl)

func _on_upgrade_chosen(upgrade_id: String) -> void:
	if _levelup_overlay:
		_levelup_overlay.queue_free()
		_levelup_overlay = null
	get_tree().paused = false
	if _levelup_callback.is_valid():
		_levelup_callback.call(upgrade_id)

# ── Stat updaters ──────────────────────────────────────────────────────────────
func update_stats(p_hp: int, p_max_hp: int, p_xp: int, p_xp_next: int, p_level: int) -> void:
	if _hp_bar:
		_hp_bar.max_value = p_max_hp
		_hp_bar.value = p_hp
	if _hp_num_label:
		_hp_num_label.text = "%d" % p_hp
	if _xp_bar:
		_xp_bar.max_value = max(1, p_xp_next)
		_xp_bar.value = p_xp
	if _level_label:
		_level_label.text = "LVL  %d" % p_level

func flash_damage() -> void:
	if not _damage_flash:
		return
	_damage_flash.color.a = 0.28
	var tween = create_tween()
	tween.tween_property(_damage_flash, "color:a", 0.0, 0.5)

func show_game_over() -> void:
	_game_over = true
	if _go_time_label:
		_go_time_label.text = "Survived  " + _fmt_time(_elapsed_time)
	if _go_overlay:
		_go_overlay.visible = true

# ── Crosshair ──────────────────────────────────────────────────────────────────
func _build_crosshair() -> void:
	var crosshair = Node2D.new()
	crosshair.set_script(preload("res://scenes/hud/crosshair.gd"))
	add_child(crosshair)

# ── Restart ────────────────────────────────────────────────────────────────────
func _on_restart_pressed() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	get_tree().reload_current_scene()

# ── Helpers ────────────────────────────────────────────────────────────────────
func _fmt_time(secs: float) -> String:
	var m: int = int(secs) / 60
	var s: int = int(secs) % 60
	return "%d:%02d" % [m, s]

func _pbox(bg: Color, border: Color, bw: int = BORDER) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left   = bw
	s.border_width_right  = bw
	s.border_width_top    = bw
	s.border_width_bottom = bw
	return s

func _apply_bar(bar: ProgressBar, bg: Color, fill: Color) -> void:
	var bg_s = StyleBoxFlat.new()
	bg_s.bg_color = bg
	var fill_s = StyleBoxFlat.new()
	fill_s.bg_color = fill
	bar.add_theme_stylebox_override("background", bg_s)
	bar.add_theme_stylebox_override("fill", fill_s)
