extends SceneTree
## Full composition with a normal Camera3D and fake controller state. XR stays off.

var checks: int = 0
var failures: int = 0

class MockRig extends XRInput:
	var focused: bool = false
	var menu_down: bool = false
	var use_reported_pose: bool = false
	var reported_pose := Transform3D.IDENTITY
	func _ready() -> void:
		camera = Camera3D.new()
		camera.fov = 78
		add_child(camera)
		reset_session()
	func tracking_usable() -> bool:
		return focused
	func is_session_focused() -> bool:
		return focused
	func menu_pressed() -> bool:
		return menu_down and focused
	func right_pointer_valid() -> bool:
		return false
	func head_world_transform() -> Transform3D:
		return reported_pose if use_reported_pose else camera.global_transform

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var garden = scene.instantiate()
	root.add_child(garden)
	garden.set_process(false)
	await process_frame
	var mock := MockRig.new()
	garden.add_child(mock)
	garden._install_xr_rig(mock)
	await process_frame
	check(garden.desktop == null and garden.rig == mock, "tracked rig replaces desktop input")
	check(not root.use_xr and not garden.get_viewport().use_xr, "mock composition never enables XR output")
	check(garden.ui.get_parent() == garden._xr_panel.viewport, "UI is rendered in the world panel viewport")
	check(garden.ui.is_open() and not mock.enabled, "initial VR menu gates navigation and interaction")
	check(not garden._xr_panel.visible, "menu waits for first head pose instead of appearing at floor")
	garden._process(0.1)
	check(not garden._xr_panel.visible, "untracked startup cannot place menu")
	# Report a valid runtime pose before Camera3D's node transform catches up.
	mock.reported_pose = mock.camera.global_transform
	mock.reported_pose.origin.y = 1.65
	mock.use_reported_pose = true
	mock.focused = true
	garden._process(0.1)
	check(garden._xr_panel.visible and is_equal_approx(garden._xr_panel.global_position.y, 1.65), "first runtime pose places menu at standing eye height despite stale camera")
	mock.camera.position.y = 1.65
	mock.use_reported_pose = false
	var anchor: Transform3D = garden._xr_panel.global_transform
	mock.camera.position.x += 0.1
	garden._process(0.1)
	check(garden._xr_panel.global_transform.is_equal_approx(anchor), "open menu remains world anchored during ordinary head motion")
	check(garden.dream.elapsed_seconds == 0.0, "VR menu pauses dream")
	mock.menu_down = true
	garden._process(0.1)
	check(not garden.ui.is_open() and mock.enabled, "menu controller press resumes")
	var elapsed: float = garden.dream.elapsed_seconds
	garden._process(0.1)
	check(not garden.ui.is_open() and garden.dream.elapsed_seconds > elapsed, "held menu does not toggle repeatedly")
	mock.menu_down = false
	garden._process(0.1)
	mock.focused = false
	elapsed = garden.dream.elapsed_seconds
	garden._process(10.0)
	check(garden.dream.elapsed_seconds == elapsed, "tracking/session loss freezes simulation")
	check(not garden._xr_navigation.transition_active(), "focus loss cancels pending navigation")
	mock.focused = true
	mock.menu_down = true
	garden._process(0.1)
	check(not garden.ui.is_open(), "held menu on focus recovery cannot toggle")
	mock.menu_down = false
	garden._process(0.1)
	mock.menu_down = true
	garden._process(0.1)
	check(garden.ui.is_open() and not mock.enabled, "released menu can reopen settings")
	mock.focused = false
	garden._process(0.1)
	mock.camera.position.y = 1.1
	mock.focused = true
	garden._process(0.1)
	check(garden._xr_panel.visible and is_equal_approx(garden._xr_panel.global_position.y, 1.1), "tracking recovery repositions menu at seated eye height")
	garden._xr_navigation.teleported.emit(Vector3(2.0, 0.0, -1.0))
	check(garden.traces.get_counts().x == 1, "teleport signal deposits one arrival seed")
	var previous_deposits: int = garden.traces.get_total_deposits()
	mock.mark_discontinuity()
	garden._process(0.1)
	check(garden.traces.get_total_deposits() == previous_deposits, "recenter/pose discontinuity does not clear memory or add seed")
	garden.reset_dream()
	await create_timer(0.32).timeout
	check(garden.traces.get_counts() == Vector2i.ZERO, "VR reset clears memory")
	check(garden._xr_navigation._external_fade > 0.0, "VR reset fades in both eyes through a 3D quad")
	check(mock.position.is_equal_approx(Vector3(0, 0, 3.8)), "VR reset restores origin")
	await create_timer(0.7).timeout
	garden._process(0.1)
	check(not garden._resetting and garden._xr_navigation._external_fade == 0.0, "VR reset finishes and removes fade")
	check(garden.ui.is_open() and garden._xr_panel.visible, "reset keeps settings accessible")
	if "--render-xr-mock" in OS.get_cmdline_user_args():
		mock.camera.rotation.x = 0.0
		garden._xr_panel.place_in_front_of_head()
		garden._xr_panel.update_head_pose(mock.head_world_transform(), true)
		await process_frame
		await RenderingServer.frame_post_draw
		var result := root.get_texture().get_image().save_png("res://docs/validation/xr_integrated.png")
		check(result == OK, "integrated world-panel screenshot saved")
	garden.audio.shutdown()
	await process_frame
	await process_frame
	garden.queue_free()
	await process_frame
	print("XR INTEGRATION CHECKS: ", checks, " failures: ", failures, "; mock Camera3D only; no runtime initialized")
	quit(1 if failures else 0)
