extends StaticBody2D

const _HEAL_SCRIPT := preload("res://scenes/pickups/heal_pickup.gd")
const _MAGNET_SCRIPT := preload("res://scenes/pickups/magnet_pickup.gd")

@export var stomp_radius: float = 80.0

var _opened: bool = false


func _ready() -> void:
	add_to_group("chests")
	# Physics layer 4 in project ("collectibles"): weapons mask this layer to open chests.
	collision_layer = 8
	collision_mask = 0
	z_index = 1


func take_damage(_amount: float) -> void:
	_open()


func _physics_process(_delta: float) -> void:
	if _opened:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and global_position.distance_to(player.global_position) <= stomp_radius:
		_open()


func _open() -> void:
	if _opened:
		return
	_opened = true
	collision_layer = 0
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
