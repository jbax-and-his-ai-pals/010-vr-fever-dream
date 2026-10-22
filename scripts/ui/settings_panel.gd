class_name DreamUI
extends CanvasLayer

signal settings_changed
signal reset_requested
signal exit_requested
signal open_changed(value: bool)

var settings: DreamSettings
var root: Control
var panel: PanelContainer
var title: Label
var status: Label
var bloom: ProgressBar
var bloom_label: Label
var debug: Label
var fade: ColorRect
var _open: bool = true
var _world_mode: bool = false
var _volume: HSlider
var _intensity: HSlider
var _seated: CheckButton
var _quality: OptionButton
var _hint: Label
var _header: Control
var _footer: Control
var _quality_cycle: Button

func setup(value: DreamSettings) -> void:
	settings = value

func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.theme = _theme()
	var header := MarginContainer.new()
	_header = header
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.add_theme_constant_override("margin_left", 36)
	header.add_theme_constant_override("margin_right", 36)
	header.add_theme_constant_override("margin_top", 30)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(header)
	var row := HBoxContainer.new()
	header.add_child(row)
	var brand := VBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(brand)
	brand.add_child(_label("L I V I N G   F E E D B A C K", 13, Color(0.52, 0.76, 0.79)))
	brand.add_child(_label("Something is taking shape.", 25, Color(0.9, 0.94, 0.95)))
	status = _label("SILK  /  00:00", 14, Color(0.65, 0.74, 0.79))
	row.add_child(status)
	var pause_button := Button.new()
	pause_button.text = "Pause · Esc"
	pause_button.pressed.connect(func() -> void: set_open(true))
	row.add_child(pause_button)
	var footer := MarginContainer.new()
	_footer = footer
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -115
	footer.add_theme_constant_override("margin_left", 36)
	footer.add_theme_constant_override("margin_right", 36)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(footer)
	var footer_row := HBoxContainer.new()
	footer_row.add_theme_constant_override("separation", 50)
	footer.add_child(footer_row)
	var instructions := VBoxContainer.new()
	instructions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_row.add_child(instructions)
	instructions.add_child(_label("DRIFT  /  DISTURB  /  DISCOVER", 12, Color(0.5, 0.76, 0.78)))
	_hint = _label("WASD drift · Mouse look · Space / Ctrl rise / sink", 15, Color(0.72, 0.79, 0.83))
	instructions.add_child(_hint)
	instructions.add_child(_label("Q / E reach   ·   M mute   ·   R reset   ·   F11 fullscreen", 12, Color(0.45, 0.54, 0.64)))
	var bloom_box := VBoxContainer.new()
	bloom_box.custom_minimum_size.x = 180
	footer_row.add_child(bloom_box)
	bloom_label = _label("PAUSE TO BLOOM", 12, Color(0.55, 0.77, 0.73))
	bloom_box.add_child(bloom_label)
	bloom = ProgressBar.new()
	bloom.show_percentage = false
	bloom.max_value = 1.0
	bloom.custom_minimum_size = Vector2(180, 4)
	bloom_box.add_child(bloom)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(470, 0)
	center.add_child(panel)
	var padding := MarginContainer.new()
	for key: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		padding.add_theme_constant_override(key, 30)
	panel.add_child(padding)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	padding.add_child(content)
	content.add_child(_label("A PLACE TO GET LOST", 12, Color(0.45, 0.79, 0.75)))
	title = _label("Enter the distortion", 30, Color(0.94, 0.95, 1.0))
	content.add_child(title)
	content.add_child(_label("WASD drift · Mouse look · Space / Ctrl rise / sink\nHold mouse buttons to disturb the passing clouds.\nEsc returns here. There is nowhere you need to go.", 17, Color(0.68, 0.76, 0.83)))
	var separator := HSeparator.new()
	content.add_child(separator)
	_volume = _slider(content, "Ambient sound", settings.volume)
	_volume.value_changed.connect(func(value: float) -> void: settings.volume = value; settings_changed.emit())
	_intensity = _slider(content, "Visual intensity", settings.visual_intensity)
	_intensity.value_changed.connect(func(value: float) -> void: settings.visual_intensity = value; settings_changed.emit())
	_seated = CheckButton.new()
	_seated.text = "Seated mode"
	_seated.button_pressed = settings.seated_mode
	_seated.toggled.connect(func(value: bool) -> void: settings.seated_mode = value; settings_changed.emit())
	content.add_child(_seated)
	var quality_row := HBoxContainer.new()
	content.add_child(quality_row)
	var quality_label := _label("Field density", 14, Color(0.68, 0.76, 0.83))
	quality_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quality_row.add_child(quality_label)
	_quality = OptionButton.new()
	_quality.add_item("Sparse · 10", DreamSettings.Quality.LOW)
	_quality.add_item("Drifting · 16", DreamSettings.Quality.DEFAULT)
	_quality.select(settings.quality_tier)
	_quality.item_selected.connect(func(index: int) -> void: settings.quality_tier = index; settings_changed.emit())
	quality_row.add_child(_quality)
	var resume := Button.new()
	resume.text = "Wander in   →"
	resume.custom_minimum_size.y = 46
	resume.pressed.connect(func() -> void: set_open(false))
	content.add_child(resume)
	var actions := HBoxContainer.new()
	content.add_child(actions)
	var reset_button := Button.new()
	reset_button.text = "Reset dream"
	reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_button.pressed.connect(func() -> void: reset_requested.emit())
	actions.add_child(reset_button)
	var exit_button := Button.new()
	exit_button.text = "Leave"
	exit_button.pressed.connect(func() -> void: exit_requested.emit())
	actions.add_child(exit_button)
	debug = _label("", 13, Color(0.7, 0.9, 0.75))
	debug.position = Vector2(36, 115)
	debug.visible = false
	root.add_child(debug)
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.01, 0.014, 0.03, 0.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _slider(parent: VBoxContainer, text: String, value: float) -> HSlider:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := _label(text, 14, Color(0.68, 0.76, 0.83))
	label.custom_minimum_size.x = 165
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	return slider

func _theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 15
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.035, 0.052, 0.085, 0.96)
	background.border_color = Color(0.16, 0.28, 0.33)
	background.set_border_width_all(1)
	background.set_corner_radius_all(18)
	theme.set_stylebox("panel", "PanelContainer", background)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var button := StyleBoxFlat.new()
		button.bg_color = Color(0.09, 0.15, 0.19) if state == "normal" else Color(0.13, 0.26, 0.29)
		button.set_corner_radius_all(7)
		button.content_margin_left = 16
		button.content_margin_right = 16
		button.content_margin_top = 10
		button.content_margin_bottom = 10
		theme.set_stylebox(state, "Button", button)
		theme.set_stylebox(state, "OptionButton", button)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.08, 0.15, 0.2)
	track.set_corner_radius_all(2)
	theme.set_stylebox("background", "ProgressBar", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.33, 0.72, 0.64)
	fill.set_corner_radius_all(2)
	theme.set_stylebox("fill", "ProgressBar", fill)
	return theme

func set_open(value: bool) -> void:
	_open = value
	panel.visible = value
	_header.visible = value and not _world_mode
	_footer.hide()
	title.text = "Inside the distortion"
	open_changed.emit(value)

func is_open() -> bool:
	return _open

func update_status(dream: DreamFrame, counts: Vector2i, fps: int) -> void:
	var names: Array[String] = ["SILK", "CORAL", "AURORA"]
	var mood := names[dream.mood_from]
	if dream.mood_to != dream.mood_from:
		mood += " → " + names[dream.mood_to]
	var seconds := int(dream.elapsed_seconds)
	status.text = "%s  /  %02d:%02d" % [mood, seconds / 60, seconds % 60]
	bloom.value = dream.stillness
	bloom_label.text = "SOMETHING IS TAKING SHAPE" if dream.stillness > 0.6 else "DRIFT THROUGH"
	var mode := "OpenXR experience" if _world_mode else "Desktop preview · XR OFF"
	debug.text = mode + "\n%d FPS · %.2f ms\n%d memories · %d curls\nBloom %.2f · intensity %.2f" % [fps, 1000.0 / maxf(float(fps), 1.0), counts.x, counts.y, dream.stillness, dream.visual_intensity]

func toggle_debug() -> void:
	debug.visible = not debug.visible

func sync_settings() -> void:
	_volume.set_value_no_signal(settings.volume)
	_intensity.set_value_no_signal(settings.visual_intensity)

func show_xr_hints() -> void:
	_hint.text = "Hands bend   ·   Stick aim / trigger teleport   ·   Stick snap turn"

func use_world_panel() -> void:
	_world_mode = true
	# Popup windows are not reliable inside a textured SubViewport. A cycle
	# button keeps density selection inside the same controller input surface.
	_header.hide()
	_footer.hide()
	panel.custom_minimum_size.x = 620
	_quality.hide()
	if _quality_cycle == null:
		_quality_cycle = Button.new()
		_quality.get_parent().add_child(_quality_cycle)
		_quality_cycle.pressed.connect(func() -> void:
			settings.quality_tier = 1 - settings.quality_tier
			_update_quality_cycle()
			settings_changed.emit())
	_update_quality_cycle()

func _update_quality_cycle() -> void:
	if _quality_cycle != null:
		_quality_cycle.text = "Sparse · 10" if settings.quality_tier == 0 else "Drifting · 16"
