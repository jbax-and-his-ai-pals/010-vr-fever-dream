extends SceneTree
## Resource generation only. Always run with --headless --xr-mode off.

func _initialize() -> void:
	var action_map := OpenXRActionMap.new()
	action_map.create_default_action_sets()
	DirAccess.make_dir_recursive_absolute("res://resources/xr")
	var result := ResourceSaver.save(action_map, "res://resources/xr/default_action_map.tres")
	print("Default action map resource saved; result=", result, "; no XR initialized.")
	quit(0 if result == OK else 1)
