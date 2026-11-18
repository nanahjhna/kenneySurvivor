extends Node

## Backward-compatible entry point for old scenes. The 3D Kenney prototype was
## removed; route any legacy scene launch into the current elemental pinball game.
func _ready() -> void:
	call_deferred("_open_current_battle")


func _open_current_battle() -> void:
	var error: Error = get_tree().change_scene_to_file("res://scenes/main.tscn")
	if error != OK:
		push_error("Could not open the current battle scene: %s" % error)
