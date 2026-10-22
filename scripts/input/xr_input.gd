class_name XRInput
extends VisitorInput
## Inert until setup() receives an already initialized interface.
## This module NEVER initializes XR or enables an XR viewport.

const Frame = preload("res://scripts/contracts/visitor_frame.gd")
var camera: Camera3D
var origin: XROrigin3D
var left_controller: XRController3D
var right_controller: XRController3D
var right_aim: XRNode3D
var left_aim: XRNode3D
var enabled: bool = true
var _interface: XRInterface
var _discontinuity: bool = true
var _previous_valid := Vector3i.ZERO
var _previous_enabled: bool = true
var _quiet_until_msec: int = 0
var _last_valid_head_world: Transform3D = Transform3D.IDENTITY
var _has_valid_head_world: bool = false
var _recenter_anchor: Transform3D = Transform3D.IDENTITY
var _recenter_pending: bool = false


func setup(initialized_interface: XRInterface) -> bool:
	if initialized_interface == null or not initialized_interface.is_initialized():
		return false
	if origin != null:
		return _interface == initialized_interface
	_interface = initialized_interface
	origin = XROrigin3D.new()
	origin.name = "XROrigin"
	add_child(origin)
	camera = XRCamera3D.new()
	camera.name = "HeadCamera"
	camera.near = 0.05
	camera.far = 90.0
	camera.current = true
	origin.add_child(camera)
	left_controller = _make_controller(&"left_hand", "LeftHand")
	right_controller = _make_controller(&"right_hand", "RightHand")
	right_aim = XRNode3D.new()
	right_aim.name = "RightAim"
	right_aim.tracker = &"right_hand"
	right_aim.pose = &"aim"
	origin.add_child(right_aim)
	left_aim = XRNode3D.new()
	left_aim.name = "LeftAim"
	left_aim.tracker = &"left_hand"
	left_aim.pose = &"aim"
	origin.add_child(left_aim)
	if _interface.has_signal("pose_recentered"):
		_interface.connect("pose_recentered", _on_pose_recentered)
	if not _interface.play_area_changed.is_connected(_on_play_area_changed):
		_interface.play_area_changed.connect(_on_play_area_changed)
	reset_session()
	return true


func _make_controller(tracker_name: StringName, node_name: String) -> XRController3D:
	var controller := XRController3D.new()
	controller.name = node_name
	controller.tracker = tracker_name
	controller.pose = &"grip"
	controller.show_when_tracked = true
	origin.add_child(controller)
	var marker := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.025
	sphere.height = 0.05
	marker.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.3, 0.9, 0.85) if tracker_name == &"left_hand" else Color(0.95, 0.5, 0.7)
	marker.material_override = material
	controller.add_child(marker)
	return controller


func is_session_focused() -> bool:
	if _interface == null or not _interface.is_initialized():
		return false
	if _interface is OpenXRInterface:
		return (_interface as OpenXRInterface).get_session_state() == OpenXRInterface.SESSION_STATE_FOCUSED
	return true


func tracking_usable() -> bool:
	if not _interface_ready() or camera == null or not is_session_focused():
		return false
	# Overall status is optional. UNKNOWN can still have a valid tracked head.
	var status := _tracking_status()
	if status != XRInterface.XR_NORMAL_TRACKING and status != XRInterface.XR_UNKNOWN_TRACKING:
		return false
	var pose := _head_pose()
	# OpenXR can publish a default pose with tracking_data=true before it has
	# head confidence. Never treat that initial identity transform as eye height.
	return pose != null and pose.has_tracking_data and pose.tracking_confidence != XRPose.XR_TRACKING_CONFIDENCE_NONE and pose.transform.is_finite()


func _interface_ready() -> bool:
	return _interface != null and _interface.is_initialized()


func _tracking_status() -> int:
	return _interface.get_tracking_status()


func _head_pose() -> XRPose:
	var tracker := XRServer.get_tracker(&"head") as XRPositionalTracker
	return tracker.get_pose(&"default") if tracker != null else null


func head_world_transform() -> Transform3D:
	# Read the same adjusted pose as XRCamera, even before its first node update.
	if camera is XRCamera3D and origin != null:
		var pose := _head_pose()
		if pose != null and pose.has_tracking_data and pose.tracking_confidence != XRPose.XR_TRACKING_CONFIDENCE_NONE:
			return origin.global_transform * pose.get_adjusted_transform()
	return camera.global_transform if camera != null else Transform3D.IDENTITY


func menu_pressed() -> bool:
	if not is_session_focused():
		return false
	for controller in [left_controller, right_controller]:
		if controller != null and controller.get_has_tracking_data() and controller.is_button_pressed(&"menu_button"):
			return true
	return left_controller != null and left_controller.get_has_tracking_data() and (left_controller.is_button_pressed(&"ax_button") or left_controller.is_button_pressed(&"by_button") or left_controller.is_button_pressed(&"primary_click"))


func trigger_value() -> float:
	if right_controller == null or not right_controller.get_has_tracking_data() or not is_session_focused():
		return 0.0
	return right_controller.get_float(&"trigger")


func right_pointer_valid() -> bool:
	return tracking_usable() and right_aim != null and right_aim.get_has_tracking_data()


func right_pointer_transform() -> Transform3D:
	return right_aim.global_transform if right_pointer_valid() else Transform3D.IDENTITY


func suppress_motion(seconds: float) -> void:
	_quiet_until_msec = maxi(_quiet_until_msec, Time.get_ticks_msec() + int(maxf(seconds, 0.0) * 1000.0))
	mark_discontinuity()


func motion_suppressed() -> bool:
	return Time.get_ticks_msec() < _quiet_until_msec


func sample() -> VisitorFrame:
	var frame := Frame.new()
	if tracking_usable() and camera != null:
		apply_recenter_if_pending()
		_last_valid_head_world = head_world_transform()
		_has_valid_head_world = true
	frame.head_valid = tracking_usable() and not motion_suppressed()
	if camera != null:
		frame.head_transform = head_world_transform()
	if left_controller != null:
		frame.left_hand_transform = left_controller.global_transform
		frame.left_hand_valid = frame.head_valid and left_controller.get_has_tracking_data()
	if right_controller != null:
		frame.right_hand_transform = right_controller.global_transform
		frame.right_hand_valid = frame.head_valid and right_controller.get_has_tracking_data()
	frame.left_hand_active = enabled and frame.left_hand_valid
	frame.right_hand_active = enabled and frame.right_hand_valid
	var valid := Vector3i(int(frame.head_valid), int(frame.left_hand_valid), int(frame.right_hand_valid))
	# Both tracking loss and recovery invalidate previous pose history.
	if valid != _previous_valid or enabled != _previous_enabled:
		mark_discontinuity()
	frame.motion_discontinuity = _discontinuity
	_discontinuity = false
	_previous_valid = valid
	_previous_enabled = enabled
	return frame


func mark_discontinuity() -> void:
	_discontinuity = true


func _on_pose_recentered() -> void:
	# Runtime may update tracked poses after emitting this signal. Capture the
	# previous world view now and compensate on the next sample, after pose update.
	_recenter_anchor = _last_valid_head_world
	_recenter_pending = _has_valid_head_world
	mark_discontinuity()


func apply_recenter_if_pending() -> void:
	if not _recenter_pending or camera == null or not tracking_usable():
		return
	global_transform = recentered_root_transform(global_transform, head_world_transform(), _recenter_anchor)
	_recenter_pending = false
	suppress_motion(0.25)


static func recentered_root_transform(root_transform: Transform3D, current_head: Transform3D, previous_head: Transform3D) -> Transform3D:
	# Reference-space changes affect only horizontal placement and yaw. Retain
	# tracked height and pitch/roll; never write a pose owned by the runtime.
	var current_forward := Vector2(current_head.basis.z.x, current_head.basis.z.z)
	var previous_forward := Vector2(previous_head.basis.z.x, previous_head.basis.z.z)
	var yaw: float = 0.0
	if current_forward.length_squared() > 0.00001 and previous_forward.length_squared() > 0.00001:
		yaw = atan2(previous_forward.x, previous_forward.y) - atan2(current_forward.x, current_forward.y)
	var turn := Basis(Vector3.UP, yaw)
	var pivot := Vector3(current_head.origin.x, 0.0, current_head.origin.z)
	var result := Transform3D(turn * root_transform.basis, pivot + turn * (root_transform.origin - pivot))
	result.origin.x += previous_head.origin.x - current_head.origin.x
	result.origin.z += previous_head.origin.z - current_head.origin.z
	return result


func _on_play_area_changed(_mode: int) -> void:
	mark_discontinuity()


func reset_session() -> void:
	# Move only the rig root; never overwrite a tracked camera/controller pose.
	position = Vector3(0.0, 0.0, 3.8)
	rotation = Vector3.ZERO
	if origin != null:
		origin.transform = Transform3D.IDENTITY
	_previous_valid = Vector3i.ZERO
	_quiet_until_msec = 0
	_has_valid_head_world = false
	_recenter_pending = false
	mark_discontinuity()


func _exit_tree() -> void:
	if _interface != null:
		if _interface.has_signal("pose_recentered") and _interface.is_connected("pose_recentered", _on_pose_recentered):
			_interface.disconnect("pose_recentered", _on_pose_recentered)
		if _interface.play_area_changed.is_connected(_on_play_area_changed):
			_interface.play_area_changed.disconnect(_on_play_area_changed)
