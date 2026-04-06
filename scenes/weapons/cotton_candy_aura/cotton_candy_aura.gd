extends Area2D

@export var tick_interval: float = 1.5
@export var aura_radius: float = 2.2

func _ready() -> void:
	var cs := $CollisionShape2D as CollisionShape2D
	var shape := CircleShape2D.new()
	shape.radius = aura_radius
	cs.shape = shape

	var sprite := $Sprite2D as Sprite2D
	var tween := sprite.create_tween()
	tween.set_loops()
	tween.tween_property(sprite, "scale", sprite.scale * 1.18, 0.9)
	tween.tween_property(sprite, "scale", sprite.scale, 0.9)

	var timer := Timer.new()
	timer.wait_time = tick_interval
	timer.autostart = true
	timer.timeout.connect(_tick_damage)
	add_child(timer)

func _tick_damage() -> void:
	for body in get_overlapping_bodies():
		if body.is_in_group("enemies"):
			body.die()
