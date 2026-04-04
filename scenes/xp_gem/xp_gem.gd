extends Node2D

var xp_amount: int = 10
var collect_radius: float = 24.0
var move_speed: float = 230.0

var _attracted: bool = false

func _ready():
	z_index = 1

func _process(delta: float) -> void:
	var player = get_tree().current_scene.get_node_or_null("Player")
	if not player:
		return

	var dist: float = global_position.distance_to(player.global_position)

	if dist <= collect_radius:
		player.add_xp(xp_amount)
		queue_free()
		return

	if not _attracted and dist <= player.gem_attract_radius:
		_attracted = true

	if _attracted:
		var dir: Vector2 = (player.global_position - global_position).normalized()
		global_position += dir * move_speed * delta

func _draw() -> void:
	# Main hexagonal gem body
	var pts := PackedVector2Array([
		Vector2(0,  -11),
		Vector2(8,   -4),
		Vector2(8,    5),
		Vector2(0,   11),
		Vector2(-8,   5),
		Vector2(-8,  -4),
	])
	draw_colored_polygon(pts, Color(0.08, 0.76, 1.00))

	# Top facet (lighter — cut gem look)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -11),
		Vector2(8,  -4),
		Vector2(0,  -1),
		Vector2(-8, -4),
	]), Color(0.38, 0.92, 1.00))

	# Dark pixel outline
	draw_polyline(PackedVector2Array([
		pts[0], pts[1], pts[2], pts[3], pts[4], pts[5], pts[0]
	]), Color(0.02, 0.10, 0.32), 2.0)

	# White shine stroke
	draw_line(Vector2(-3, -9), Vector2(2, -4), Color(1.0, 1.0, 1.0, 0.82), 1.5)
