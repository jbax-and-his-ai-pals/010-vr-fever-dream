extends SceneTree

var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var field := TraceField.new()
	root.add_child(field)
	var visitor := VisitorFrame.new()
	var dream := DreamFrame.new()
	visitor.head_transform.origin = Vector3(0, 1.6, 0)
	field.update_frame(visitor, dream, 0.1)
	visitor.head_transform.origin.x = 0.2
	field.update_frame(visitor, dream, 0.1)
	check(field.get_counts().x == 1, "travel deposits once")
	visitor.motion_discontinuity = true
	visitor.head_transform.origin.x = 5.0
	field.update_frame(visitor, dream, 0.1)
	check(field.get_counts().x == 1, "teleport creates no connector")
	visitor.motion_discontinuity = false
	visitor.head_valid = false
	field.update_frame(visitor, dream, 35.0)
	check(field.get_counts().y == 1, "selected trace matures")
	field.update_frame(visitor, dream, 55.0)
	check(field.get_counts() == Vector2i.ZERO, "trace and curl expire together")
	field.add_arrival_seed(Vector3(2, 1, 3))
	check(field.get_counts().x == 1, "one teleport arrival seed")
	field.reset_session()
	check(field.get_counts() == Vector2i.ZERO, "reset clears pools")
	visitor.head_valid = true
	visitor.left_hand_valid = true
	visitor.left_hand_active = true
	visitor.right_hand_valid = true
	visitor.right_hand_active = true
	for i in 6000:
		var point := Vector3(sin(i * 0.08) * 2.0, 1.6, cos(i * 0.08) * 2.0)
		visitor.head_transform.origin = point
		visitor.left_hand_transform.origin = point + Vector3(0.3, 0, 0)
		visitor.right_hand_transform.origin = point - Vector3(0.3, 0, 0)
		field.update_frame(visitor, dream, 0.1)
		var counts := field.get_counts()
		if counts.x > 256 or counts.y > 64:
			check(false, "pool exceeded cap")
			break
	check(field.get_total_deposits() > 256, "ten-minute fixture exercises pool recycling")
	check(field.get_counts().x <= 256 and field.get_counts().y <= 64, "pools bounded after 600 seconds")
	var before := field.get_total_deposits()
	visitor.head_valid = false
	visitor.left_hand_valid = false
	visitor.right_hand_active = false
	field.update_frame(visitor, dream, 0.2)
	check(field.get_total_deposits() == before, "invalid and inactive sources deposit nothing")
	field.queue_free()
	await process_frame
	print("TRACE CHECKS: ", checks, " failures: ", failures)
	quit(1 if failures > 0 else 0)
