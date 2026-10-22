extends Node3D

var settings := DreamSettings.new()
var rig: VisitorInput
var desktop: DesktopInput
var ribbons: RibbonField
var traces: TraceField
var audio: AudioDriver
var motion := MotionSampler.new()
var director := DreamDirector.new()
var ui: DreamUI
var dream := DreamFrame.new()
var stage: GardenStage
var _resetting: bool = false
var _muted_volume: float = 0.5
var _capture_path: String = ""
var _capture_mood: int = -1
var _capture_bloom: float = -1.0
var _capture_frames: int = 0
var _capture_menu: bool = false
var _smoke: bool = false
var _smoke_seconds: float = 0.0
var _xr_navigation: XRNavigation
var _xr_rig: XRInput
var _xr_panel: XRPanel
var _menu_was_down: bool = false
var _xr_focused_previous: bool = false
var _reset_fade_alpha: float = 0.0
var _quitting: bool = false

func _ready() -> void:
	get_tree().auto_accept_quit = false
	_parse_arguments()
	stage = GardenStage.new()
	stage.name = "GardenStage"
	add_child(stage)
	desktop = DesktopInput.new()
	desktop.name = "VisitorRig"
	desktop.automated = _smoke or not _capture_path.is_empty()
	rig = desktop
	add_child(rig)
	ribbons = RibbonField.new()
	ribbons.name = "RibbonField"
	add_child(ribbons)
	traces = TraceField.new()
	traces.name = "TraceField"
	add_child(traces)
	# Keep bounded memory logic, but leave the fluid space free of drawn trails.
	traces.hide()
	audio = AudioDriver.new()
	audio.name = "AudioDriver"
	add_child(audio)
	ui = DreamUI.new()
	ui.name = "SettingsPanel"
	ui.setup(settings)
	add_child(ui)
	ui.settings_changed.connect(_apply_settings)
	ui.open_changed.connect(_on_menu_changed)
	ui.reset_requested.connect(reset_dream)
	ui.exit_requested.connect(quit_garden)
	_apply_settings()
	_on_menu_changed(true)
	if _smoke or not _capture_path.is_empty():
		ui.set_open(_capture_menu)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_enable_xr()
	if _xr_rig == null:
		print("Living Feedback Garden: desktop mode; OpenXR not accessed by scene.")

func _parse_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			_capture_path = argument.trim_prefix("--capture=")
		elif argument.begins_with("--capture-mood="):
			_capture_mood = clampi(argument.trim_prefix("--capture-mood=").to_int(), 0, 2)
		elif argument.begins_with("--capture-bloom="):
			_capture_bloom = clampf(argument.trim_prefix("--capture-bloom=").to_float(), 0.0, 1.0)
		elif argument == "--smoke":
			_smoke = true
		elif argument == "--capture-menu":
			_capture_menu = true

func _process(delta: float) -> void:
	var visitor: VisitorFrame
	var focused := true
	if _xr_rig:
		focused = _xr_rig.tracking_usable()
		var menu_down := _xr_rig.menu_pressed()
		if focused and _xr_focused_previous and menu_down and not _menu_was_down and not _resetting:
			ui.set_open(not ui.is_open())
		_menu_was_down = menu_down
		if focused != _xr_focused_previous:
			_xr_rig.mark_discontinuity()
			motion.reset_session()
			_xr_navigation.cancel_navigation()
		_xr_focused_previous = focused
		audio.set_paused(ui.is_open() or not focused or _resetting)
		if focused and not ui.is_open() and not _resetting:
			_xr_navigation.advance(delta, settings)
			_rebase_space()
		visitor = _xr_rig.sample()
		# Place only after sampling applies pending reference-space changes.
		_xr_panel.update_head_pose(_xr_rig.head_world_transform(), focused)
		var pointer := _xr_rig.right_pointer_transform()
		_xr_panel.update_pointer(pointer.origin, -pointer.basis.z, _xr_rig.trigger_value() > 0.6, focused and not _resetting and _xr_rig.right_pointer_valid())
	if focused and not ui.is_open() and not _resetting:
		if desktop:
			desktop.advance(delta)
			_rebase_space()
			visitor = desktop.sample()
		advance_frame(delta, visitor)
	ui.update_status(dream, traces.get_counts(), int(Engine.get_frames_per_second()))
	if not _capture_path.is_empty():
		_capture_frames += 1
		if _capture_frames == 120:
			_capture_view()
	if _smoke:
		_smoke_seconds += delta
		if _smoke_seconds >= 600.0:
			print("SMOKE PASS: 600 simulated seconds; pools ", traces.get_counts(), "; ribbons ", ribbons.get_instance_count())
			quit_garden()

func advance_frame(delta: float, visitor: VisitorFrame) -> void:
	var sound := audio.sample(delta)
	var stillness := motion.update(visitor, delta, settings)
	dream = director.step(delta, stillness, settings)
	if not _capture_path.is_empty():
		if _capture_mood >= 0:
			dream.mood_from = _capture_mood
			dream.mood_to = _capture_mood
			dream.mood_blend = 0.0
		if _capture_bloom >= 0.0:
			dream.stillness = _capture_bloom
	ribbons.apply_frame(visitor, dream, sound)
	stage.apply_frame(dream, visitor)
	traces.update_frame(visitor, dream, delta)

func _rebase_space() -> void:
	# Keep rendered coordinates small during long journeys without limiting travel.
	var offset := rig.global_position
	if offset.abs()[offset.abs().max_axis_index()] > 256.0:
		rig.global_position -= offset
		ribbons.shift_origin(offset)
		stage.shift_origin(offset)
		if _xr_panel:
			_xr_panel.global_position -= offset
		if _xr_navigation:
			_xr_navigation.cancel_navigation()
		traces.reset_session()
		rig.mark_discontinuity()

func _apply_settings() -> void:
	audio.set_volume(settings.volume)
	ribbons.set_quality(settings.quality_tier)

func _on_menu_changed(value: bool) -> void:
	if desktop:
		desktop.enabled = not value
		desktop.mark_discontinuity()
	if _xr_rig:
		_xr_rig.enabled = not value
		_xr_rig.mark_discontinuity()
		_xr_navigation.cancel_navigation()
		motion.reset_session()
	audio.set_paused(value)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value or not desktop else Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				ui.set_open(not ui.is_open())
			KEY_F3:
				ui.toggle_debug()
			KEY_F11:
				var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
			KEY_R:
				if not ui.is_open():
					reset_dream()
			KEY_M:
				if settings.volume > 0.0:
					_muted_volume = settings.volume
					settings.volume = 0.0
				else:
					settings.volume = _muted_volume
				_apply_settings()
				ui.sync_settings()
			KEY_ENTER:
				if ui.is_open():
					ui.set_open(false)

func reset_dream() -> void:
	if _resetting:
		return
	_resetting = true
	if _xr_navigation:
		_xr_navigation.cancel_navigation()
	var tween := create_tween()
	tween.tween_method(_set_reset_fade, 0.0, 1.0, 0.25)
	await tween.finished
	reset_session()
	_set_reset_fade(1.0)
	var reveal := create_tween()
	reveal.tween_method(_set_reset_fade, 1.0, 0.0, 0.65)
	await reveal.finished
	_resetting = false

func _set_reset_fade(alpha: float) -> void:
	_reset_fade_alpha = alpha
	if _xr_navigation:
		_xr_navigation.set_external_fade(alpha)
	else:
		ui.fade.color.a = alpha

func reset_session() -> void:
	rig.reset_session()
	motion.reset_session()
	director.reset_session()
	traces.reset_session()
	ribbons.reset_session()
	audio.reset_session()
	dream = DreamFrame.new()
	stage.apply_frame(dream)
	if _xr_navigation:
		_xr_navigation.reset_session()
	if _xr_panel and ui.is_open():
		_xr_panel.place_in_front_of_head()

func _capture_view() -> void:
	await RenderingServer.frame_post_draw
	var screenshot := get_viewport().get_texture().get_image()
	var result := screenshot.save_png(_capture_path)
	print("CAPTURE: ", _capture_path, " result=", result)
	quit_garden(0 if result == OK else 1)

func quit_garden(exit_code: int = 0) -> void:
	if _quitting:
		return
	_quitting = true
	set_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	audio.shutdown()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(exit_code)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and audio:
		quit_garden()

func _enable_xr() -> void:
	var project_xr: bool = ProjectSettings.get_setting("xr/openxr/enabled", false)
	if not XRStartup.request_allowed(OS.get_cmdline_args(), OS.get_cmdline_user_args(), DisplayServer.get_name() == "headless", project_xr):
		return
	var resolver := func() -> Object: return XRServer.find_interface("OpenXR")
	var interface := XRStartup.select_interface(OS.get_cmdline_args(), OS.get_cmdline_user_args(), DisplayServer.get_name() == "headless", resolver, project_xr) as XRInterface
	if interface == null:
		push_warning("VR unavailable or disabled. Continuing in desktop preview; use Launch-VR.ps1 when a Windows OpenXR runtime is ready.")
		return
	var xr := XRInput.new()
	xr.name = "XRVisitorRig"
	add_child(xr)
	if not xr.setup(interface):
		xr.queue_free()
		push_warning("VR rig setup failed. Continuing in desktop preview.")
		return
	_install_xr_rig(xr)
	get_viewport().use_xr = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	print("Living Feedback Garden: OpenXR rig active; world-space settings enabled.")

func _install_xr_rig(xr: XRInput) -> void:
	# Separate composition from runtime lookup so mocked-camera fixtures can test
	# the integration without initializing or enabling an XR viewport.
	if desktop:
		desktop.enabled = false
		desktop.camera.current = false
		desktop.queue_free()
		desktop = null
	rig = xr
	_xr_rig = xr
	xr.camera.current = true
	_xr_navigation = XRNavigation.new()
	add_child(_xr_navigation)
	_xr_navigation.setup(xr)
	_xr_navigation.teleported.connect(_on_teleported)
	_xr_panel = XRPanel.new()
	add_child(_xr_panel)
	_xr_panel.setup(ui, xr.camera, true)
	_on_menu_changed(ui.is_open())
	motion.reset_session()

func _on_teleported(position: Vector3) -> void:
	traces.add_arrival_seed(position)
	motion.reset_session()
