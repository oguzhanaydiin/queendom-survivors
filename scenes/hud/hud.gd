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

# layout constants
const BORDER     = 3
const STRIP_H    = 38
const LVL_W      = 80
const HP_ICON_W  = 38
const HP_STRIP_W = 224
const HP_PAD     = 14
const TIMER_H    = 26
const TIMER_GAP  = 4
const MODAL_W    = 480
const MODAL_H    = 280

# Palette
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

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root = Control.new()
	root.name = "HUDRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_xp_strip(root)
	_build_timer_label(root)
	_build_hp_strip(root)
	_build_damage_flash(root)
	_build_game_over(root)

func _process(delta: float) -> void:
	if _game_over:
		return
	_elapsed_time += delta
	if _timer_label:
		_timer_label.text = _fmt_time(_elapsed_time)

# XP bar
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

# Timer bar
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

# HP bar
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
	heart_panel.size = Vector2(HP_ICON_W, STRIP_H)
	heart_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heart_panel.add_theme_stylebox_override("panel", _pbox(C_HEART_BG, C_HP_BDR))
	strip.add_child(heart_panel)

	var heart_lbl = Label.new()
	heart_lbl.text = "♥"
	heart_lbl.position = Vector2(0, 0)
	heart_lbl.size = Vector2(HP_ICON_W, STRIP_H)
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
	_hp_bar.offset_left   = HP_ICON_W + BORDER
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
	_hp_num_label.offset_left   = HP_ICON_W
	_hp_num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_num_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_num_label.add_theme_font_size_override("font_size", 14)
	_hp_num_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_hp_num_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_hp_num_label.add_theme_constant_override("outline_size", 3)
	_hp_num_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(_hp_num_label)

# Screen flash on damage
func _build_damage_flash(root: Control) -> void:
	_damage_flash = ColorRect.new()
	_damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_flash.color = Color(1.0, 0.0, 0.0, 0.0)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_damage_flash)

# Game over overlay
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

# stat functions
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

# Helpers
func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _fmt_time(secs: float) -> String:
	var m: int = int(secs) / 60
	var s: int = int(secs) % 60
	return "%d:%02d" % [m, s]

func _pbox(bg: Color, border: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left   = BORDER
	s.border_width_right  = BORDER
	s.border_width_top    = BORDER
	s.border_width_bottom = BORDER
	return s

func _apply_bar(bar: ProgressBar, bg: Color, fill: Color) -> void:
	var bg_s = StyleBoxFlat.new()
	bg_s.bg_color = bg
	var fill_s = StyleBoxFlat.new()
	fill_s.bg_color = fill
	bar.add_theme_stylebox_override("background", bg_s)
	bar.add_theme_stylebox_override("fill", fill_s)
