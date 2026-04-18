extends Node2D

@export var explosion_radius: float = 80.0
@export var fuse_time: float = 1.2
@export var damage: float = 24.0

var _shadow: Polygon2D

func _ready() -> void:
	var sprite := $Sprite2D as Sprite2D

	# Landing spot in world space (must not move with the falling bomb)
	var land_global := global_position
	var land_y: float = position.y

	# Shadow stays fixed on the ground — NOT a child of this node (bomb tweens position.y)
	_shadow = _make_ring(explosion_radius * 0.55, Color(0.2, 0.1, 0.0, 0.30))
	_shadow.global_position = land_global
	get_tree().current_scene.add_child(_shadow)
	var shadow_tween := _shadow.create_tween()
	shadow_tween.set_loops()
	shadow_tween.tween_property(_shadow, "modulate:a", 0.6, fuse_time * 0.4)
	shadow_tween.tween_property(_shadow, "modulate:a", 0.2, fuse_time * 0.4)

	# Drop from above
	position.y -= 220
	sprite.scale = Vector2(0.02, 0.02)

	# Fall tween
	var fall := create_tween()
	fall.tween_property(self, "position:y", land_y, fuse_time * 0.55).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	fall.parallel().tween_property(sprite, "scale", Vector2(0.072, 0.072), fuse_time * 0.55)
	# Land bounce
	fall.tween_property(self, "position:y", land_y - 14, 0.08)
	fall.tween_property(self, "position:y", land_y, 0.08)
	# Fuse pulse while waiting
	fall.tween_property(sprite, "scale", Vector2(0.082, 0.082), 0.12)
	fall.tween_property(sprite, "scale", Vector2(0.064, 0.064), 0.12)
	fall.tween_property(sprite, "scale", Vector2(0.082, 0.082), 0.12)
	fall.tween_property(sprite, "scale", Vector2(0.064, 0.064), 0.12)
	fall.tween_callback(_explode)

func _make_ring(radius: float, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	var verts := PackedVector2Array()
	for i in range(32):
		var a := TAU * i / 32
		verts.append(Vector2(cos(a), sin(a)) * radius)
	poly.polygon = verts
	poly.color   = color
	return poly

func _explode() -> void:
	if is_instance_valid(_shadow):
		_shadow.queue_free()
		_shadow = null
	if not is_inside_tree():
		return
	var boom_pos := global_position
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and boom_pos.distance_to(enemy.global_position) <= explosion_radius:
			enemy.take_damage(damage)
	for chest in get_tree().get_nodes_in_group("chests"):
		if is_instance_valid(chest) and boom_pos.distance_to(chest.global_position) <= explosion_radius:
			WeaponHitHelper.deal_weapon_damage(chest, damage)

	# Expanding explosion ring
	var ring := Node2D.new()
	ring.global_position = boom_pos
	var poly := _make_ring(8.0, Color(1.0, 0.78, 0.20, 0.85))
	ring.add_child(poly)
	get_tree().current_scene.add_child(ring)

	var boom_tween := poly.create_tween()
	boom_tween.tween_property(poly, "scale", Vector2(explosion_radius / 8.0, explosion_radius / 8.0), 0.25).set_ease(Tween.EASE_OUT)
	boom_tween.parallel().tween_property(poly, "color", Color(1.0, 0.5, 0.1, 0.0), 0.25)
	boom_tween.tween_callback(ring.queue_free)

	queue_free()
