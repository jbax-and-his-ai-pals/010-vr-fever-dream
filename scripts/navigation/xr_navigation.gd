class_name XRNavigation
extends Node3D
## Flat-floor prototype navigation. No XR initialization, headset assumptions,
## physical camera animation, or continuous artificial locomotion.

signal teleported(position: Vector3)

const Rig = preload("res://scripts/input/xr_input.gd")
const SNAP_RADIANS: float = PI / 6.0
const MAX_RADIUS: float = INF
const MAX_AIM_DISTANCE: float = 12.0
const FADE_OUT_SECONDS: float = 0.12
const FADE_IN_SECONDS: float = 0.16
const POST_MOVE_QUIET_SECONDS: float = 0.25

var rig: Rig
var target_valid: bool = false
var target_position: Vector3 = Vector3.ZERO
var _marker: MeshInstance3D
var _marker_material: StandardMaterial3D
var _fade: MeshInstance3D
var _fade_material: StandardMaterial3D
var _aiming: bool = false
var _turn_latched: bool = false
var _fade_time: float = -1.0
var _pending_turn: float = 0.0
var _pending_target: Vector3
var _pending_teleport: bool = false
var _committed: bool = false
var _trigger_latched: bool = true
var _quiet_time: float = 0.0
var _external_fade: float = 0.0
var _navigation_fade: float = 0.0


func setup(visitor_rig: Rig) -> void:
	rig = visitor_rig
	if rig == null or rig.camera == null:
		return
	_marker = MeshInstance3D.new()
	_marker.name = "TeleportTarget"
	var disk := CylinderMesh.new()
	disk.top_radius = 0.22
	disk.bottom_radius = 0.22
	disk.height = 0.008
	_marker.mesh = disk
	_marker_material = StandardMaterial3D.new()
	_marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker.material_override = _marker_material
	_marker.visible = false
	add_child(_marker)
	_fade = MeshInstance3D.new()
	_fade.name = "NavigationFade"
	var quad := QuadMesh.new()
	quad.size = Vector2(4.0, 4.0)
	_fade.mesh = quad
	_fade.position.z = -0.1
	_fade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fade_material = StandardMaterial3D.new()
	_fade_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fade_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fade_material.no_depth_test = true
	_fade_material.disable_fog = true
	_fade_material.render_priority = 127
	_fade.material_override = _fade_material
	_fade.visible = false
	rig.camera.add_child(_fade)
	reset_session()


func advance(delta: float, _settings: DreamSettings) -> void:
	if rig == null or not rig.enabled or not rig.tracking_usable():
		cancel_navigation()
		return
	if _external_fade > 0.0:
		return
	if _fade_time >= 0.0:
		_advance_fade(maxf(delta, 0.0))
		return
	if _quiet_time > 0.0:
		_quiet_time = maxf(0.0, _quiet_time - maxf(delta, 0.0))
		return
	if not _controller_valid():
		cancel_navigation()
		return
	var stick: Vector2 = _controller_stick()
	var trigger: bool = _controller_trigger() > 0.6
	if not trigger:
		_trigger_latched = false
	# One snap per deflection, rearm only after stick returns close to center.
	if absf(stick.x) < 0.3:
		_turn_latched = false
	if absf(stick.x) > 0.7 and absf(stick.y) < 0.5 and not _turn_latched and not _aiming:
		_turn_latched = true
		_begin_transition(false, Vector3.ZERO, -signf(stick.x) * SNAP_RADIANS)
		return
	if _trigger_latched:
		return
	if trigger:
		_aiming = true
		_update_target()
	elif _aiming:
		_aiming = false
		# Refresh validity on release; a lost aim pose never commits a stale point.
		_update_target()
		if target_valid:
			_begin_transition(true, target_position, 0.0)
		if _marker != null:
			_marker.visible = false


func _controller_valid() -> bool:
	return rig.right_controller != null and rig.right_controller.get_has_tracking_data()


func _controller_stick() -> Vector2:
	return rig.right_controller.get_vector2(&"primary")


func _controller_trigger() -> float:
	return rig.trigger_value()


func _update_target() -> void:
	target_valid = false
	if rig.right_aim == null or not rig.right_aim.get_has_tracking_data():
		if _marker != null:
			_marker.visible = false
		return
	var ray_origin: Vector3 = rig.right_aim.global_position
	var ray_direction: Vector3 = -rig.right_aim.global_basis.z
	var hit: Variant = floor_intersection(ray_origin, ray_direction)
	if hit == null:
		if _marker != null:
			_marker.visible = false
		return
	target_position = hit as Vector3
	target_valid = teleport_target_valid(target_position)
	_marker.global_position = target_position + Vector3(0.0, 0.014, 0.0)
	_marker_material.albedo_color = Color(0.3, 0.9, 0.65) if target_valid else Color(0.75, 0.24, 0.2)
	_marker.visible = _aiming


func _begin_transition(is_teleport: bool, destination: Vector3, turn: float) -> void:
	_pending_teleport = is_teleport
	_pending_target = destination
	_pending_turn = turn
	_committed = false
	_fade_time = 0.0
	if _marker != null:
		_marker.visible = false
	_set_fade(0.0)


func _advance_fade(delta: float) -> void:
	_fade_time += delta
	if _fade_time >= FADE_OUT_SECONDS and not _committed:
		_committed = true
		_set_fade(1.0)
		var root_transform: Transform3D = rig.global_transform
		var head_world: Vector3 = rig.camera.global_position
		if _pending_teleport and teleport_target_valid(_pending_target):
			rig.global_transform = teleport_origin_transform(root_transform, head_world, _pending_target)
			rig.mark_discontinuity()
			rig.suppress_motion(POST_MOVE_QUIET_SECONDS)
			teleported.emit(_pending_target)
		elif not _pending_teleport:
			rig.global_transform = snap_origin_transform(root_transform, head_world, _pending_turn)
			rig.mark_discontinuity()
			rig.suppress_motion(POST_MOVE_QUIET_SECONDS)
		_quiet_time = POST_MOVE_QUIET_SECONDS
		# Render one fully opaque frame at the movement tick even when delta
		# steps past the fade-out boundary.
		_fade_time = FADE_OUT_SECONDS
		_set_fade(1.0)
		return
	if _fade_time < FADE_OUT_SECONDS:
		_set_fade(_fade_time / FADE_OUT_SECONDS)
	else:
		_set_fade(1.0 - (_fade_time - FADE_OUT_SECONDS) / FADE_IN_SECONDS)
	if _fade_time >= FADE_OUT_SECONDS + FADE_IN_SECONDS:
		_fade_time = -1.0
		_set_fade(0.0)


func _set_fade(alpha: float) -> void:
	_navigation_fade = clampf(alpha, 0.0, 1.0)
	_render_fade()


func _render_fade() -> void:
	var alpha := maxf(_external_fade, _navigation_fade)
	if _fade != null:
		_fade.visible = alpha > 0.001
		_fade_material.albedo_color = Color(0.0, 0.0, 0.0, clampf(alpha, 0.0, 1.0))


func cancel_navigation() -> void:
	_aiming = false
	_turn_latched = true
	_trigger_latched = true
	target_valid = false
	_fade_time = -1.0
	if _marker != null:
		_marker.visible = false
	_set_fade(0.0)
	_pending_teleport = false
	_pending_turn = 0.0
	_committed = false
	_quiet_time = 0.0


func transition_active() -> bool:
	return _fade_time >= 0.0 or _external_fade > 0.0 or _quiet_time > 0.0


func set_external_fade(alpha: float) -> void:
	_external_fade = clampf(alpha, 0.0, 1.0)
	_render_fade()


func reset_session() -> void:
	cancel_navigation()
	_external_fade = 0.0
	_render_fade()
	_pending_teleport = false
	_committed = false


static func teleport_target_valid(destination: Vector3, radius: float = MAX_RADIUS) -> bool:
	return destination.is_finite() and not is_nan(radius) and radius > 0.0 and absf(destination.y) <= 0.001 and Vector2(destination.x, destination.z).length() <= radius


static func floor_intersection(ray_origin: Vector3, ray_direction: Vector3) -> Variant:
	if not ray_origin.is_finite() or not ray_direction.is_finite() or ray_origin.y < 0.0:
		return null
	var direction: Vector3 = ray_direction.normalized()
	if direction.y >= -0.05:
		return null
	var distance: float = -ray_origin.y / direction.y
	if distance < 0.0 or distance > MAX_AIM_DISTANCE:
		return null
	var hit: Vector3 = ray_origin + direction * distance
	hit.y = 0.0
	return hit


static func snap_origin_transform(root_transform: Transform3D, head_world: Vector3, radians: float) -> Transform3D:
	var pivot := Vector3(head_world.x, 0.0, head_world.z)
	var turn := Basis(Vector3.UP, radians)
	return Transform3D(turn * root_transform.basis, pivot + turn * (root_transform.origin - pivot))


static func teleport_origin_transform(root_transform: Transform3D, head_world: Vector3, destination: Vector3) -> Transform3D:
	var result: Transform3D = root_transform
	# Land the tracked head floor projection, not the reference-space origin.
	result.origin.x += destination.x - head_world.x
	result.origin.z += destination.z - head_world.z
	return result


func _exit_tree() -> void:
	# Fade is attached to the camera, so clean it if navigation is replaced alone.
	if is_instance_valid(_fade):
		_fade.queue_free()
