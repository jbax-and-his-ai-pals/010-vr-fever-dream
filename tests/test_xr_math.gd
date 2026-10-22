extends SceneTree

const Rig = preload("res://scripts/input/xr_input.gd")
const Navigation = preload("res://scripts/navigation/xr_navigation.gd")
var failures: int = 0


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var rig := Rig.new()
	root.add_child(rig)
	_check(not rig.setup(null), "Inert setup accepted null interface")
	_check(rig.camera == null and rig.origin == null, "XR nodes created without initialized interface")
	_check(not rig.is_session_focused(), "Absent interface reported focused session")
	_check(not rig.menu_pressed() and rig.trigger_value() == 0.0, "Inert rig exposed controller input")
	_check(not rig.right_pointer_valid(), "Inert rig reported valid pointer")
	var first = rig.sample()
	_check(not first.head_valid and not first.left_hand_valid and not first.right_hand_valid, "Absent tracking marked valid")
	_check(first.motion_discontinuity, "Initial frame must reset samples")
	_check(not rig.sample().motion_discontinuity, "Discontinuity never clears")
	rig.mark_discontinuity()
	_check(rig.sample().motion_discontinuity, "Explicit discontinuity lost")
	rig.enabled = false
	_check(rig.sample().motion_discontinuity, "Pause did not mark discontinuity")
	rig.enabled = true
	_check(rig.sample().motion_discontinuity, "Resume did not mark discontinuity")
	_check(Navigation.teleport_target_valid(Vector3(7.0, 0.0, 0.0)), "Boundary point rejected")
	_check(Navigation.teleport_target_valid(Vector3(700.0, 0.0, 0.0)), "Endless traversal target rejected")
	_check(not Navigation.teleport_target_valid(Vector3(7.001, 0.0, 0.0), 7.0), "Explicit target radius ignored")
	_check(not Navigation.teleport_target_valid(Vector3(0.0, 0.1, 0.0)), "Non-floor target accepted")
	_check(not Navigation.teleport_target_valid(Vector3(NAN, 0.0, 0.0)), "Non-finite target accepted")
	_check(Navigation.floor_intersection(Vector3(0.0, 1.5, 0.0), Vector3(0.0, -1.0, -1.0)) != null, "Downward aim misses floor")
	_check(Navigation.floor_intersection(Vector3(0.0, 1.5, 0.0), Vector3.FORWARD) == null, "Horizontal aim accepted")
	_check(Navigation.floor_intersection(Vector3(0.0, 1.5, 0.0), Vector3.UP) == null, "Upward aim accepted")
	_check(Navigation.floor_intersection(Vector3(0.0, 1.5, 0.0), Vector3(0.0, -0.06, -1.0)) == null, "Overlong aim accepted")
	var root_transform := Transform3D(Basis(Vector3.UP, 0.4), Vector3(2.0, 0.0, -3.0))
	var local_head := Vector3(0.75, 1.65, -0.3)
	var world_head: Vector3 = root_transform * local_head
	var snapped: Transform3D = Navigation.snap_origin_transform(root_transform, world_head, PI / 6.0)
	_check((snapped * local_head).distance_to(world_head) < 0.00001, "Snap moves physically offset head")
	_check(snapped.basis.y.distance_to(Vector3.UP) < 0.00001, "Snap adds roll/pitch")
	var destination := Vector3(-4.0, 0.0, 2.0)
	var teleported: Transform3D = Navigation.teleport_origin_transform(root_transform, world_head, destination)
	var arrived: Vector3 = teleported * local_head
	_check(Vector2(arrived.x, arrived.z).distance_to(Vector2(destination.x, destination.z)) < 0.00001, "Teleport lands origin instead of head floor")
	_check(absf(arrived.y - world_head.y) < 0.00001, "Teleport changes tracked head height")
	_check(teleported.basis.is_equal_approx(root_transform.basis), "Teleport changes heading")
	var full_circle: Transform3D = root_transform
	for index in 12:
		full_circle = Navigation.snap_origin_transform(full_circle, world_head, PI / 6.0)
	_check(full_circle.is_equal_approx(root_transform), "Twelve snap turns drift")
	# Resource construction only: inspects installed default action names without
	# creating/initializing an XR interface or requesting a headset runtime.
	var action_map := OpenXRActionMap.new()
	action_map.create_default_action_sets()
	var names: Array[String] = []
	for action_set in action_map.action_sets:
		for action in action_set.actions:
			names.append(action.resource_name)
	for required in ["trigger", "primary", "primary_click", "menu_button", "ax_button", "by_button", "grip_pose", "aim_pose"]:
		_check(required in names, "Missing default action " + required)
	print("XR scaffold fixture: no initialized XR, tracking absent, discontinuity, floor/radius rejection, physical head offset teleport and 30deg snap; failures=", failures)
	print("Installed default action map names: ", names)
	rig.queue_free()
	quit(1 if failures > 0 else 0)
