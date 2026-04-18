extends StaticBody2D

const _HEAL_SCRIPT := preload("res://scenes/pickups/heal_pickup.gd")
const _MAGNET_SCRIPT := preload("res://scenes/pickups/magnet_pickup.gd")

@export var stomp_radius: float = 80.0

var _opening: bool = false


func _ready() -> void:
	add_to_group("chests")
	# Physics layer 4 in project ("collectibles"): weapons mask this layer to open chests.
	collision_layer = 8
	collision_mask = 0
	z_index = 1


func take_damage(_amount: float) -> void:
	_begin_open()


func _physics_process(_delta: float) -> void:
	if _opening:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and global_position.distance_to(player.global_position) <= stomp_radius:
		_begin_open()


func _begin_open() -> void:
	if _opening:
		return
	_opening = true
	collision_layer = 0

	var spr := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if spr and spr.sprite_frames and spr.sprite_frames.has_animation("open"):
		spr.sprite_frames.set_animation_loop("open", false)
		spr.play("open")
		spr.animation_finished.connect(_on_open_anim_finished, CONNECT_ONE_SHOT)
	else:
		_finish_open()


func _on_open_anim_finished() -> void:
	if not is_inside_tree():
		return
	_finish_open()


func _finish_open() -> void:
	_spawn_loot()
	queue_free()


func _chest_sprite_center_global() -> Vector2:
	if has_node("AnimatedSprite2D"):
		return get_node("AnimatedSprite2D").global_position
	if has_node("Sprite2D"):
		return get_node("Sprite2D").global_position
	return global_position


func _spawn_loot() -> void:
	var parent := get_tree().current_scene
	if not parent:
		return
	var drop_pos := _chest_sprite_center_global()
	var node := Node2D.new()
	if randf() < 0.5:
		node.set_script(_HEAL_SCRIPT)
	else:
		node.set_script(_MAGNET_SCRIPT)
	parent.add_child(node)
	node.global_position = drop_pos
