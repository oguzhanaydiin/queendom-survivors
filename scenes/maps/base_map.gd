class_name BaseMap
extends Node2D

# Called by World after the player is instantiated and added to the scene.
# Subclasses use this to start chunk generation anchored to the player.
func initialize(player_node: Node2D) -> void:
	pass

func get_display_name() -> String:
	return ""
