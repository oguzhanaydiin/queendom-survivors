class_name PickupVisualScale
extends RefCounted
## Matches chest `AnimatedSprite2D`: atlas 40×32, scale 1.4 — icons stay slightly under that footprint.

const _CHEST_ATLAS_W := 40.0
const _CHEST_ATLAS_H := 32.0
const _CHEST_NODE_SCALE := 1.4
const _VS_CHEST := 0.88

static func _chest_max_px() -> float:
	return maxf(_CHEST_ATLAS_W * _CHEST_NODE_SCALE, _CHEST_ATLAS_H * _CHEST_NODE_SCALE)


static func uniform_icon_scale(texture: Texture2D) -> float:
	var sz: Vector2 = texture.get_size()
	var max_px: float = maxf(sz.x, sz.y)
	if max_px < 1.0:
		return 0.5
	return (_chest_max_px() * _VS_CHEST) / max_px


static func collect_radius_for_scale(tex_size: Vector2, uniform_s: float) -> float:
	var w: float = tex_size.x * uniform_s
	var h: float = tex_size.y * uniform_s
	return maxf(40.0, maxf(w, h) * 0.42)
