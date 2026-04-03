extends Area2D

var speed = 300.0
var direction = Vector2.RIGHT
var lifetime = 3.0

func _ready():
	rotation = direction.angle()
	var timer = get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)

func _physics_process(delta):
	position += direction * speed * delta

func _on_body_entered(body):
	if body.is_in_group("enemies"):
		body.die()
		queue_free()
