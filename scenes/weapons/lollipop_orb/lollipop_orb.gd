extends Area2D

var damage: float = 10.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	WeaponHitHelper.deal_weapon_damage(body, damage)
