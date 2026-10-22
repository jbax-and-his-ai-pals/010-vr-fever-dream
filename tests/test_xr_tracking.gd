extends SceneTree
## Synthetic head tracker only. No interface or headset runtime is initialized.

const Rig = preload("res://scripts/input/xr_input.gd")
var failures: int = 0
var checks: int = 0

class MockRig extends Rig:
	var interface_ready: bool = true
	var focused: bool = true
	var status: int = XRInterface.XR_UNKNOWN_TRACKING
	func _interface_ready() -> bool:
		return interface_ready
	func is_session_focused() -> bool:
		return focused
	func _tracking_status() -> int:
		return status

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var previous_tracker := XRServer.get_tracker(&"head")
	if previous_tracker != null:
		XRServer.remove_tracker(previous_tracker)
	var rig := MockRig.new()
	root.add_child(rig)
	rig.origin = XROrigin3D.new()
	rig.add_child(rig.origin)
	rig.camera = Camera3D.new()
	rig.origin.add_child(rig.camera)
	_check(not rig.tracking_usable(), "Missing head tracker accepted")
	var tracker := XRPositionalTracker.new()
	tracker.name = &"head"
	tracker.type = XRServer.TRACKER_HEAD
	XRServer.add_tracker(tracker)
	_check(not rig.tracking_usable(), "Missing default pose accepted")
	var pose_transform := Transform3D(Basis(Vector3.UP, 0.45), Vector3(0.2, 1.65, -0.3))
	tracker.set_pose(&"default", pose_transform, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_NONE)
	_check(not rig.tracking_usable(), "Startup pose without confidence accepted")
	tracker.set_pose(&"default", pose_transform, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	_check(rig.tracking_usable(), "UNKNOWN status rejected valid head tracking")
	rig.status = XRInterface.XR_NORMAL_TRACKING
	_check(rig.tracking_usable(), "NORMAL status rejected valid head tracking")
	for status in [XRInterface.XR_EXCESSIVE_MOTION, XRInterface.XR_INSUFFICIENT_FEATURES, XRInterface.XR_NOT_TRACKING]:
		rig.status = status
		_check(not rig.tracking_usable(), "Degraded tracking status accepted: %s" % status)
	rig.status = XRInterface.XR_UNKNOWN_TRACKING
	rig.focused = false
	_check(not rig.tracking_usable(), "Unfocused session accepted")
	rig.focused = true
	rig.interface_ready = false
	_check(not rig.tracking_usable(), "Uninitialized interface accepted")
	rig.interface_ready = true
	tracker.invalidate_pose(&"default")
	_check(not rig.tracking_usable(), "Stale head pose accepted")
	tracker.set_pose(&"default", pose_transform, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_LOW)
	_check(rig.tracking_usable(), "Available low-confidence head pose rejected")
	var invalid_transform := pose_transform
	invalid_transform.origin.x = NAN
	tracker.set_pose(&"default", invalid_transform, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	_check(not rig.tracking_usable(), "Nonfinite head pose accepted")
	tracker.set_pose(&"default", pose_transform, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	rig.position = Vector3(3.0, 0.0, 4.0)
	rig.rotation.y = 0.3
	rig.camera.position.y = 1.1
	_check(rig.head_world_transform().is_equal_approx(rig.camera.global_transform), "Ordinary camera mock transform changed")
	rig.camera.free()
	# XRCamera is inert with XR disabled; creating the node does not initialize XR.
	rig.camera = XRCamera3D.new()
	rig.origin.add_child(rig.camera)
	rig.camera.transform = Transform3D.IDENTITY
	var expected := rig.origin.global_transform * tracker.get_pose(&"default").get_adjusted_transform()
	_check(rig.head_world_transform().is_equal_approx(expected), "Pose placement used stale floor-level camera transform")
	var frame := rig.sample()
	_check(frame.head_valid, "Valid synthetic head was not sampled")
	_check(frame.head_transform.is_equal_approx(expected), "Sample did not use current adjusted head pose")
	tracker.invalidate_pose(&"default")
	frame = rig.sample()
	_check(not frame.head_valid and frame.motion_discontinuity, "Head tracking loss did not reset motion history")
	tracker.set_pose(&"default", pose_transform, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	frame = rig.sample()
	_check(frame.head_valid and frame.motion_discontinuity, "Head tracking recovery did not reset motion history")
	rig.free()
	XRServer.remove_tracker(tracker)
	if previous_tracker != null:
		XRServer.add_tracker(previous_tracker)
	print("XR TRACKING: %s checks, %s failures; synthetic poses, XR disabled." % [checks, failures])
	quit(1 if failures else 0)
