extends SceneTree

const PanelScript = preload("res://scripts/ui/xr_panel.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _point_at(panel: PanelScript, pixel: Vector2, pressed: bool) -> void:
	var target := panel.to_global(Vector3((pixel.x / panel.PIXEL_SIZE.x - 0.5) * panel.WORLD_SIZE.x, (0.5 - pixel.y / panel.PIXEL_SIZE.y) * panel.WORLD_SIZE.y, 0.0))
	var origin := panel.global_position + panel.global_basis.z
	panel.update_pointer(origin, target - origin, pressed)

func _click(panel: PanelScript, control: Control) -> void:
	var pixel := control.get_global_rect().get_center()
	_point_at(panel, pixel, false)
	_point_at(panel, pixel, true)
	_point_at(panel, pixel, false)

func _button(ui: DreamUI, text: String) -> Button:
	for child in ui.root.find_children("*", "Button", true, false):
		if child.text == text:
			return child
	return null

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0.0, 1.2, 0.0)
	camera.current = true
	var ui := DreamUI.new()
	ui.setup(DreamSettings.new())
	root.add_child(ui)
	var panel := PanelScript.new()
	world.add_child(panel)
	panel.setup(ui, camera)
	await process_frame
	await process_frame
	_check(panel.global_basis.y.is_equal_approx(Vector3.UP), "Panel acquired roll/pitch")
	_check(is_equal_approx(panel.global_position.y, 1.2), "Panel ignores seated head height")
	var center: Variant = panel.ray_to_pixel(camera.global_position, -camera.global_basis.z)
	_check(center != null and center.distance_to(Vector2(panel.PIXEL_SIZE) * 0.5) < 0.01, "Center ray mapping failed")
	_check(panel.ray_to_pixel(camera.global_position, Vector3.UP) == null, "Parallel ray hit")
	_check(panel.ray_to_pixel(camera.global_position, camera.global_basis.z) == null, "Backward ray hit")
	_check(panel.ray_to_pixel(Vector3(NAN, 0, 0), Vector3.FORWARD) == null, "Non-finite ray hit")
	_check(panel.ray_to_pixel(camera.global_position, Vector3(2, 0, -1)) == null, "Outside bounds hit")
	_check(panel.ray_to_pixel(panel.global_position + panel.global_basis.z * 6, -panel.global_basis.z) == null, "Overlong ray hit")
	panel.rotate_y(0.6)
	var angled_origin := panel.global_position + panel.global_basis.z
	var rotated: Variant = panel.ray_to_pixel(angled_origin, -panel.global_basis.z)
	_check(rotated != null and rotated.distance_to(Vector2(panel.PIXEL_SIZE) * 0.5) < 0.01, "Rotated panel mapping failed")
	var old_quality := ui.settings.quality_tier
	_click(panel, ui._quality_cycle)
	_check(ui.settings.quality_tier != old_quality, "Controller click failed density cycle")
	var old_seated := ui.settings.seated_mode
	_click(panel, ui._seated)
	_check(ui.settings.seated_mode != old_seated, "Controller click failed seated toggle")
	var rect := ui._volume.get_global_rect()
	_point_at(panel, rect.position + Vector2(rect.size.x * 0.1, rect.size.y * 0.5), true)
	_point_at(panel, rect.position + Vector2(rect.size.x * 0.8, rect.size.y * 0.5), true)
	_point_at(panel, rect.position + Vector2(rect.size.x * 0.8, rect.size.y * 0.5), false)
	_check(ui.settings.volume > 0.65, "Controller slider drag failed")
	rect = ui._intensity.get_global_rect()
	_point_at(panel, rect.position + Vector2(rect.size.x * 0.9, rect.size.y * 0.5), true)
	_point_at(panel, rect.position + Vector2(rect.size.x * 0.9, rect.size.y * 0.5), false)
	_check(ui.settings.visual_intensity > 0.8, "Controller intensity slider failed")
	_point_at(panel, rect.position + Vector2(rect.size.x * 0.8, rect.size.y * 0.5), true)
	var intensity_before_loss := ui.settings.visual_intensity
	panel.update_pointer(Vector3.ZERO, Vector3.FORWARD, true, false)
	_check(is_equal_approx(ui.settings.visual_intensity, intensity_before_loss), "Tracking cancellation changed slider value")
	_point_at(panel, Vector2(panel.PIXEL_SIZE) * 0.5, false)
	var signals := [0, 0]
	ui.reset_requested.connect(func() -> void: signals[0] += 1)
	ui.exit_requested.connect(func() -> void: signals[1] += 1)
	_click(panel, _button(ui, "Reset dream"))
	_click(panel, _button(ui, "Leave"))
	_check(signals == [1, 1], "Controller reset/exit signals failed")
	_point_at(panel, _button(ui, "Reset dream").get_global_rect().get_center(), true)
	panel.update_pointer(Vector3.ZERO, Vector3.FORWARD, true, false)
	_check(signals[0] == 1, "Tracking loss activated reset on release")
	_point_at(panel, _button(ui, "Reset dream").get_global_rect().get_center(), true)
	_check(not panel._pressed, "Held trigger reactivated after tracking loss")
	_point_at(panel, Vector2(panel.PIXEL_SIZE) * 0.5, false)
	_point_at(panel, Vector2(panel.PIXEL_SIZE) * 0.5, true)
	panel.update_pointer(Vector3.ZERO, Vector3.FORWARD, true, false)
	_check(not panel._pressed and not panel.cursor.visible, "Tracking loss left pointer pressed")
	_click(panel, _button(ui, "Wander in   →"))
	_check(not panel.visible and not panel._pressed, "Closed menu retains surface/input")
	ui.set_open(true)
	_check(panel.visible, "Menu failed to reopen")
	_point_at(panel, _button(ui, "Reset dream").get_global_rect().get_center(), true)
	_check(not panel._pressed and signals[0] == 1, "Held trigger activated reopened menu")
	_point_at(panel, Vector2(panel.PIXEL_SIZE) * 0.5, false)
	# Optional desktop render proof. This never initializes an XR runtime.
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/validation/xr_panel.png")
	print("XR world panel mocked-ray fixture: failures=", failures)
	quit(1 if failures > 0 else 0)
