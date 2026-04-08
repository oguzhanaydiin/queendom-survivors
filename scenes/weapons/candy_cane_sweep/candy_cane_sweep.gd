extends Area2D

@export var sweep_radius: float = 90.0

func _ready() -> void:
	var cs := $CollisionShape2D as CollisionShape2D
	var shape := CircleShape2D.new()
	shape.radius = sweep_radius
	cs.shape = shape

	body_entered.connect(_on_body_entered)

	# Spin 3 candy canes in a circle for 0.5s
	var count := 3
	for i in range(count):
		var sprite := Sprite2D.new()
		sprite.texture = $Sprite2D.texture
		# Match pre-resize look: ~texture_width * scale ≈ 1376 * 0.10 → scale ≈ 0.8 @ 172px wide.
		sprite.scale   = Vector2(0.8, 0.8)
		var angle_offset := TAU * i / count
		sprite.position = Vector2(cos(angle_offset), sin(angle_offset)) * sweep_radius * 0.6
		sprite.rotation = angle_offset
		add_child(sprite)

		var tween := sprite.create_tween()
		tween.set_loops(0)
		tween.tween_property(sprite, "rotation", sprite.rotation + TAU, 0.5)

	# Fade out then free
	var fade := $Sprite2D.create_tween()
	$Sprite2D.visible = false
	fade.tween_interval(0.5)
	fade.tween_callback(queue_free)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		body.die()
