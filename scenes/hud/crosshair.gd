extends Node2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _process(_delta: float) -> void:
	position = get_viewport().get_mouse_position()
	queue_redraw()

func _draw() -> void:
	const GAP    = 5.0   # empty space around center
	const LEN    = 11.0  # line length
	const THICK  = 1.5
	const COL    = Color(1.0, 1.0, 1.0, 0.92)
	const SHADOW = Color(0.0, 0.0, 0.0, 0.45)

	var lines := [
		[Vector2(0, -GAP), Vector2(0, -(GAP + LEN))],
		[Vector2(0,  GAP), Vector2(0,   GAP + LEN)],
		[Vector2(-GAP, 0), Vector2(-(GAP + LEN), 0)],
		[Vector2( GAP, 0), Vector2(  GAP + LEN,  0)],
	]

	for l in lines:
		draw_line(l[0] + Vector2(1, 1), l[1] + Vector2(1, 1), SHADOW, THICK)
		draw_line(l[0], l[1], COL, THICK)

	draw_circle(Vector2.ZERO, 1.5, SHADOW)
	draw_circle(Vector2.ZERO, 1.2, COL)
