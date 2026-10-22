extends SceneTree

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)

func run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var garden = scene.instantiate()
	root.add_child(garden)
	garden.set_process(false)
	await process_frame
	check(garden.ui.is_open(), "initial menu is open")
	check((DisplayServer.get_name() == "headless" or "--desktop" in OS.get_cmdline_user_args()) and not root.use_xr, "test startup stays desktop despite project XR default")
	check(garden.desktop != null and garden._xr_navigation == null, "desktop rig only")
	garden._process(5.0)
	check(garden.dream.elapsed_seconds == 0.0, "menu pauses dream timer")
	key(KEY_ENTER)
	await process_frame
	check(not garden.ui.is_open(), "Enter dismisses welcome")
	check(garden.desktop.enabled, "desktop movement enabled after menu")
	check(not garden.ui._header.visible and not garden.ui._footer.visible, "exploration leaves the view free of HUD")
	if DisplayServer.get_name() != "headless":
		var start_position: Vector3 = garden.desktop.position
		Input.action_press("move_forward")
		garden.desktop.advance(0.5)
		Input.action_release("move_forward")
		check(garden.desktop.position.z < start_position.z - 0.5, "WASD moves forward in desktop mode")
		var start_height: float = garden.desktop.position.y
		Input.action_press("float_up")
		garden.desktop.advance(0.5)
		Input.action_release("float_up")
		check(garden.desktop.position.y > start_height + 0.5, "Space rises through the fluid")
		Input.action_press("float_down")
		garden.desktop.advance(0.5)
		Input.action_release("float_down")
		check(is_equal_approx(garden.desktop.position.y, start_height), "Ctrl sinks through the fluid")
		var start_yaw: float = garden.desktop.rotation.y
		var mouse_motion := InputEventMouseMotion.new()
		mouse_motion.relative = Vector2(120, 0)
		Input.parse_input_event(mouse_motion)
		await process_frame
		check(garden.desktop.rotation.y < start_yaw - 0.1, "captured mouse changes desktop look")
		Input.action_press("hand_farther")
		garden.desktop.advance(0.2)
		Input.action_release("hand_farther")
		check(garden.desktop.hand_reach > 1.4, "hand reach control changes pose distance")
	else:
		print("Headless: movement/mouse/reach checks require visible display; skipped5.")
	garden.desktop.automated = true
	var initial_nodes := get_node_count()
	var frame := VisitorFrame.new()
	frame.left_hand_valid = true
	frame.right_hand_valid = true
	frame.left_hand_active = true
	frame.right_hand_active = true
	for i in 6000:
		var position := Vector3(sin(i * 0.08) * 2.0, 1.65, cos(i * 0.08) * 2.0)
		frame.head_transform.origin = position
		frame.left_hand_transform.origin = position + Vector3(-0.3, -0.2, -1)
		frame.right_hand_transform.origin = position + Vector3(0.3, -0.2, -1)
		garden.advance_frame(0.1, frame)
	check(absf(garden.dream.elapsed_seconds - 600.0) < 0.01, "600 seconds integrated simulation")
	check(get_node_count() == initial_nodes, "simulation does not accumulate nodes")
	check(garden.traces.get_counts().x <= 256 and garden.traces.get_counts().y <= 64, "integrated trace pools stay capped")
	check(garden.traces.get_total_deposits() > 256, "integrated simulation exercises recycling")
	var frozen: float = garden.dream.elapsed_seconds
	key(KEY_ESCAPE)
	await process_frame
	garden._process(5.0)
	check(garden.ui.is_open() and garden.dream.elapsed_seconds == frozen, "Escape pauses time")
	key(KEY_M)
	await process_frame
	check(garden.settings.volume == 0.0 and garden.audio.volume == 0.0, "mute synchronizes settings and audio")
	key(KEY_M)
	await process_frame
	check(garden.settings.volume == 0.5, "mute toggle restores previous volume")
	garden.settings.quality_tier = DreamSettings.Quality.LOW
	garden._apply_settings()
	check(garden.ribbons.get_instance_count() == 10, "low density sets10")
	garden.reset_session()
	check(garden.dream.elapsed_seconds == 0.0 and garden.traces.get_counts() == Vector2i.ZERO, "reset clears time and traces")
	frame = garden.desktop.sample()
	check(frame.motion_discontinuity, "reset marks pose discontinuity")
	garden.advance_frame(0.1, frame)
	check(garden.traces.get_counts() == Vector2i.ZERO, "reset does not generate connector")
	for i in 100:
		garden.advance_frame(0.1, frame)
		frame.motion_discontinuity = false
	check(garden.dream.stillness > 0.95, "integrated stillness blooms")
	check(garden.dream.mood_from == DreamFrame.Mood.SILK, "reset returns to Silk")
	garden.audio.shutdown()
	await process_frame
	await process_frame
	garden.queue_free()
	await process_frame
	print("INTEGRATION CHECKS: ", checks, " failures: ", failures)
	quit(1 if failures > 0 else 0)
