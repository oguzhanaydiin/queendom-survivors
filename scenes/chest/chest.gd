extends StaticBody2D

const _HEAL_SCRIPT := preload("res://scenes/pickups/heal_pickup.gd")
const _MAGNET_SCRIPT := preload("res://scenes/pickups/magnet_pickup.gd")

@export var stomp_radius: float = 52.0

var _opened: bool = false


func _ready() -> void:
	add_to_group("chests")
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


func _spawn_loot() -> void:
	var parent := get_tree().current_scene
	if not parent:
		return
	var count := randi_range(1, 3)
	var base_angle := randf() * TAU
	for i in range(count):
		var kind := "heal" if randf() < 0.5 else "magnet"
		var node := Node2D.new()
		if kind == "heal":
			node.set_script(_HEAL_SCRIPT)
		else:
			node.set_script(_MAGNET_SCRIPT)
		var a := base_angle + TAU * float(i) / float(count) + randf_range(-0.25, 0.25)
		var r := randf_range(18.0, 36.0)
		node.global_position = global_position + Vector2(cos(a), sin(a)) * r
		parent.add_child(node)
