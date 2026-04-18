extends Node2D

const _TEX := preload("res://assets/sprites/magnet.png")

@export var collect_radius: float = 22.0
@export var move_speed: float = 220.0
@export var pulse_duration: float = 4.5

var _attracted: bool = false


func _ready() -> void:
	z_index = 1
	var s := Sprite2D.new()
	s.texture = _TEX
	s.scale = Vector2(0.07, 0.07)
	add_child(s)


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return

	var dist: float = global_position.distance_to(player.global_position)

	if dist <= collect_radius:
		if player.has_method("apply_magnet_pulse"):
			player.apply_magnet_pulse(pulse_duration)
		queue_free()
		return

	var attract_r: float = _attract_radius(player)
	if not _attracted and dist <= attract_r:
		_attracted = true

	if _attracted:
		var dir: Vector2 = (player.global_position - global_position).normalized()
		global_position += dir * move_speed * delta


func _attract_radius(player: Node2D) -> float:
	if player.has_method("get_effective_gem_attract_radius"):
		return player.get_effective_gem_attract_radius()
	return float(player.get("gem_attract_radius"))
