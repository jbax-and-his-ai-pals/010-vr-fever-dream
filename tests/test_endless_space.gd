extends SceneTree
## Bounded streaming and personal-space regression. Never initializes XR.

var checks: int = 0
var failures: int = 0
var elapsed: float = 0.0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func step(field: RibbonField, visitor: VisitorFrame, dream: DreamFrame, audio: AudioFrame, count: int) -> void:
	for index in range(count):
		elapsed += 1.0 / 60.0
		dream.elapsed_seconds = elapsed
		field.apply_frame(visitor, dream, audio)

func run() -> void:
	var rendered := DisplayServer.get_name() != "headless"
	check(not root.use_xr and "--desktop" in OS.get_cmdline_user_args(), "fixture explicitly stays desktop")
	var world := Node3D.new()
	root.add_child(world)
	var field := RibbonField.new()
	world.add_child(field)
	var visitor := VisitorFrame.new()
	var dream := DreamFrame.new()
	var audio := AudioFrame.new()
	visitor.head_valid = true
	visitor.head_transform.origin = Vector3(0.0, 1.65, 3.8)
	step(field, visitor, dream, audio, 1)
	var node_count := get_node_count()
	var bounded_homes := true
	var bounded_forms := true
	var finite := true
	for travel in range(1, 81):
		visitor.head_transform.origin = Vector3(travel * 83.0, travel * -47.0, travel * 61.0)
		step(field, visitor, dream, audio, 1)
		for index in range(field._homes.size()):
			var home_delta: Vector3 = field._homes[index].origin - visitor.head_transform.origin
			bounded_homes = bounded_homes and maxf(absf(home_delta.x), maxf(absf(home_delta.y), absf(home_delta.z))) <= 12.01
			var form: Transform3D = field._current[index]
			finite = finite and form.origin.is_finite() and form.basis.is_finite()
			bounded_forms = bounded_forms and form.origin.distance_to(visitor.head_transform.origin) < 30.0
	check(bounded_homes, "streaming keeps homes in the viewer's 24 metre cube after long travel in all axes")
	check(bounded_forms and finite, "clouds remain nearby and finite after thousands of metres of travel")
	check(field.get_instance_count() == 16 and field._field.multimesh.instance_count == 16 and get_node_count() == node_count, "long travel reuses the same sixteen forms and nodes")

	# Approach the centre directly, including the otherwise undefined zero-distance case.
	var target := field._current[0].origin
	visitor.head_transform.origin = target
	var initial_response: float = field._responses[0]
	step(field, visitor, dream, audio, 1)
	var moved: Transform3D = field._current[0]
	var home: Transform3D = field._homes[0]
	var envelope := maxf(home.basis.x.length(), maxf(home.basis.y.length(), home.basis.z.length())) * 1.65 + 0.85 + 0.9
	check(moved.origin.is_finite() and moved.origin.distance_to(target) >= envelope - 0.01, "approaching a cloud centre pushes its full envelope out of personal space")
	check(field._responses[0] > initial_response, "approach also increases cloud transformation response")
	var peak_response: float = field._responses[0]
	var escape_direction: Vector3 = (moved.origin - home.origin).normalized()
	if escape_direction.length_squared() < 0.5:
		escape_direction = Vector3.RIGHT
	visitor.head_transform.origin = home.origin - escape_direction * 10.0
	step(field, visitor, dream, audio, 1)
	check(field._responses[0] > 0.0 and field._responses[0] < peak_response, "withdrawal starts gradual recovery rather than clearing the response instantly")
	step(field, visitor, dream, audio, 600)
	check(field._responses[0] < peak_response * 0.01, "distortion response releases smoothly when the visitor withdraws")

	var before: Transform3D = field._current[0]
	var before_home: Transform3D = field._homes[0]
	var shift := Vector3(3000.0, -2000.0, 4000.0)
	field.shift_origin(shift)
	var after: Transform3D = field._current[0]
	check(field._homes[0].origin.is_equal_approx(before_home.origin - shift), "origin rebasing shifts streaming homes")
	check(after.origin.is_equal_approx(before.origin - shift), "origin rebasing preserves displaced clouds")
	field.reset_session()
	var cleared := true
	for response in field._responses:
		cleared = cleared and is_zero_approx(response)
	check(field.get_instance_count() == 16 and cleared, "reset retains bounded pool and clears visitor distortion")

	var desktop := DesktopInput.new()
	world.add_child(desktop)
	if rendered:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		for axis in ["move_right", "move_left", "move_forward", "move_back", "float_up", "float_down"]:
			desktop.reset_session()
			var start := desktop.position
			Input.action_press(axis)
			desktop.advance(20.0)
			Input.action_release(axis)
			check(desktop.position.distance_to(start) > 30.0, "%s continues beyond the former horizontal and vertical limits" % axis)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		print("Headless: six captured movement checks require a visible display; skipped.")

	var garden = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(garden)
	garden.set_process(false)
	await process_frame
	garden.desktop.position = Vector3(310.0, -400.0, 500.0)
	var before_head: Vector3 = garden.desktop.sample().head_transform.origin
	garden.advance_frame(1.0 / 60.0, garden.desktop.sample())
	var relative_cloud: Vector3 = garden.ribbons._current[0].origin - before_head
	var before_phase: Vector3 = garden.stage._flow_phase
	garden._rebase_space()
	var after_visitor: VisitorFrame = garden.desktop.sample()
	var relative_after: Vector3 = garden.ribbons._current[0].origin - after_visitor.head_transform.origin
	check(garden.desktop.global_position.is_zero_approx(), "main origin rebase keeps visitor coordinates near zero")
	check(relative_after.is_equal_approx(relative_cloud), "main origin rebase preserves cloud positions relative to the visitor")
	check(after_visitor.motion_discontinuity, "origin rebase suppresses a false movement impulse")
	garden.advance_frame(1.0 / 60.0, after_visitor)
	check(garden.stage._flow_phase.is_equal_approx(before_phase), "origin rebase preserves fluid travel phase")
	check(garden.stage._shell.global_position.is_equal_approx(after_visitor.head_transform.origin), "enclosing atmosphere follows the viewer beyond former world edges")
	garden.audio.shutdown()
	await process_frame
	await process_frame
	garden.queue_free()
	world.queue_free()
	await process_frame
	print("ENDLESS SPACE CHECKS: ", checks, " failures: ", failures)
	quit(1 if failures > 0 else 0)
