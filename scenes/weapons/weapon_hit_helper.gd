class_name WeaponHitHelper
extends RefCounted
## Shared hit rules for projectiles / melee so chests and enemies stay in sync.

static func deal_weapon_damage(body: Node2D, damage: float) -> bool:
	if not body.has_method("take_damage"):
		return false
	if body.is_in_group("enemies"):
		body.take_damage(damage)
		return true
	if body.is_in_group("chests"):
		body.take_damage(damage)
		return true
	return false
