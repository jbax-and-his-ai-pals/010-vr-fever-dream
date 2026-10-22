class_name DesktopInput
extends VisitorInput

var camera: Camera3D
var left_marker: MeshInstance3D
var right_marker: MeshInstance3D
var enabled: bool = true
var hand_reach: float = 1.4
var speed: float = 1.8
var _pitch: float = 0.0
var _discontinuity: bool = true
var automated: bool = false
var automation_time: float = 0.0

func _ready() -> void:
	_register_inputs()
	camera = Camera3D.new()
	camera.name = "DesktopCamera"
	camera.position.y = 1.65
	camera.fov = 78.0
	camera.far = 90.0
	camera.current = true
	add_child(camera)
	left_marker = _make_hand(Color(0.25, 0.95, 0.88))
	right_marker = _make_hand(Color(1.0, 0.54, 0.72))
	_update_hands()
	reset_session()

func _register_inputs() -> void:
	var bindings: Dictionary = {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "float_up": KEY_SPACE, "float_down": KEY_CTRL, "hand_closer": KEY_Q, "hand_farther": KEY_E}
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = bindings[action]
			InputMap.action_add_event(action, event)

func _make_hand(color: Color) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.025
	sphere.height = 0.05
	marker.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	marker.material_override = material
	camera.add_child(marker)
	return marker

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or automated:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * 0.0022
		_pitch = clampf(_pitch - event.relative.y * 0.0022, -1.15, 1.15)
		camera.rotation.x = _pitch

func advance(delta: float) -> void:
	if not enabled:
		return
	if automated:
		automation_time += delta
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var axis := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var motion := global_basis * Vector3(axis.x, 0.0, axis.y)
	motion.y = Input.get_axis("float_down", "float_up")
	if motion.length_squared() > 1.0:
		motion = motion.normalized()
	position += motion * speed * delta
	hand_reach = clampf(hand_reach + Input.get_axis("hand_closer", "hand_farther") * delta, 0.5, 2.3)
	_update_hands()

func _update_hands() -> void:
	left_marker.position = Vector3(-0.32, -0.22, -hand_reach)
	right_marker.position = Vector3(0.32, -0.22, -hand_reach)

func sample() -> VisitorFrame:
	var frame := VisitorFrame.new()
	frame.head_transform = camera.global_transform
	frame.left_hand_transform = left_marker.global_transform
	frame.right_hand_transform = right_marker.global_transform
	frame.left_hand_valid = true
	frame.right_hand_valid = true
	frame.left_hand_active = enabled and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	frame.right_hand_active = enabled and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if automated:
		frame.left_hand_active = true
		frame.right_hand_active = true
		frame.left_hand_transform.origin += Vector3(sin(automation_time) * 0.4, sin(automation_time * 0.7) * 0.2, 0.0)
		frame.right_hand_transform.origin += Vector3(cos(automation_time) * 0.4, 0.0, 0.0)
	frame.motion_discontinuity = _discontinuity
	_discontinuity = false
	# The influence is visible in the clouds; keep proxy hands out of the void.
	left_marker.hide()
	right_marker.hide()
	return frame

func mark_discontinuity() -> void:
	_discontinuity = true

func reset_session() -> void:
	position = Vector3(0.0, 0.0, 3.8)
	rotation = Vector3.ZERO
	_pitch = -0.04
	if camera:
		camera.rotation.x = _pitch
	_discontinuity = true
