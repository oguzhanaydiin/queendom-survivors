extends Area2D

var speed: float      = 260.0
var direction: Vector2 = Vector2.RIGHT
var lifetime: float   = 3.0
var damage: float     = 8.0

func _ready() -> void:
	rotation = direction.angle()
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if WeaponHitHelper.deal_weapon_damage(body, damage):
		queue_free()
