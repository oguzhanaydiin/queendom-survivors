extends Area2D

@export var tick_interval: float = 1.5
@export var aura_radius: float = 2.2
@export var damage: float = 8.0

## Opaque art bounds inside cotton_candy.png (1376×768); rest is empty transparency.
const _ART_REGION := Rect2(458, 88, 460, 598)
const _ART_AXIS := 598.0
## Hidden between ticks; tick shows a translucent “shine” only (not full opaque).
const _IDLE := Color(1, 1, 1, 0)
const _PULSE := Color(1.06, 1.04, 1.1, 0.44)
const _HIT := Color(1.1, 1.06, 1.14, 0.58)
const _FIT := 1.28

var _base_sprite_scale: Vector2
var _pulse_tween: Tween
var _tick_acc: float = 0.0

func _ready() -> void:
	z_index = 40
	z_as_relative = false
	set_physics_process(true)
	monitoring = true

	var cs := $CollisionShape2D as CollisionShape2D
	var shape := CircleShape2D.new()
	shape.radius = aura_radius
	cs.shape = shape

	var sprite := $Sprite2D as Sprite2D
	sprite.z_index = 1
	sprite.z_as_relative = false
	sprite.centered = true
	sprite.region_enabled = true
	sprite.region_rect = _ART_REGION
	_base_sprite_scale = _compute_scale(aura_radius)
	sprite.scale = _base_sprite_scale
	sprite.modulate = _IDLE

	# First pulse soon so you immediately see the weapon.
	_tick_acc = tick_interval


func _compute_scale(r: float) -> Vector2:
	var diameter := 2.0 * r
	var s := (diameter / _ART_AXIS) * _FIT
	s = clampf(s, 0.006, 0.22)
	return Vector2.ONE * s


func _physics_process(delta: float) -> void:
	_tick_acc += delta
	while _tick_acc >= tick_interval:
		_tick_acc -= tick_interval
		_run_tick()


func _run_tick() -> void:
	var hit_any := false
	for body in get_overlapping_bodies():
		if body.is_in_group("enemies") and body.has_method("take_damage"):
			hit_any = true
			body.take_damage(damage)
	_play_pulse(hit_any)


func _play_pulse(strong: bool) -> void:
	if _pulse_tween != null and is_instance_valid(_pulse_tween):
		_pulse_tween.kill()
	var sprite := $Sprite2D as Sprite2D
	var peak: Color = _HIT if strong else _PULSE
	var bump: Vector2 = _base_sprite_scale * (1.3 if strong else 1.18)

	# Instant pop (reliable every tick), short hold, then ease back — Color tweens alone were too subtle.
	_pulse_tween = create_tween()
	_pulse_tween.tween_callback(func() -> void:
		sprite.modulate = peak
		sprite.scale = bump
	)
	_pulse_tween.tween_interval(0.09 if strong else 0.07)
	_pulse_tween.set_parallel(true)
	_pulse_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(sprite, "modulate", _IDLE, 0.28 if strong else 0.22)
	_pulse_tween.tween_property(sprite, "scale", _base_sprite_scale, 0.28 if strong else 0.22)
