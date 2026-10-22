class_name MotionSampler
extends RefCounted

## Stillness is the bloom envelope, not instantaneous inverse speed.
const MOTION_THRESHOLD: float = 0.08
const SPEED_SMOOTH_SECONDS: float = 0.25
const ROTATION_RADIUS: float = 0.15
const BLOOM_DELAY: float = 3.0
const BLOOM_FULL_TIME: float = 8.0
const BLOOM_DECAY_TIME: float = 2.0

var smoothed_speed: float = 0.0
var _quiet_seconds: float = 0.0
var _bloom: float = 0.0
var _previous: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY, Transform3D.IDENTITY]
var _had_pose: Array[bool] = [false, false, false]

func update(visitor: VisitorFrame, delta: float, settings: DreamSettings) -> float:
	if visitor.motion_discontinuity:
		reset_session()
		return 0.0
	if not is_finite(delta) or delta <= 0.000001:
		# Paused samples must not become a high-speed connector on resume.
		_had_pose.fill(false)
		return _bloom
	var poses: Array[Transform3D] = [visitor.head_transform, visitor.left_hand_transform, visitor.right_hand_transform]
	var valid: Array[bool] = [visitor.head_valid, visitor.left_hand_valid, visitor.right_hand_valid]
	var weights: Array[float] = [0.65, 0.175, 0.175]
	if settings.seated_mode:
		weights = [0.85, 0.075, 0.075]
	var total_weight: float = 0.0
	var weighted_speed: float = 0.0
	for index in range(3):
		valid[index] = valid[index] and _pose_is_finite(poses[index])
		if valid[index]:
			var speed: float = 0.0
			if _had_pose[index]:
				var distance: float = poses[index].origin.distance_to(_previous[index].origin)
				var rotation: float = poses[index].basis.orthonormalized().get_rotation_quaternion().angle_to(_previous[index].basis.orthonormalized().get_rotation_quaternion())
				speed = (distance + rotation * ROTATION_RADIUS) / delta
			weighted_speed += speed * weights[index]
			total_weight += weights[index]
			_previous[index] = poses[index]
		_had_pose[index] = valid[index]
	if total_weight <= 0.0:
		# No tracking is not evidence of a natural pause.
		reset_session()
		return 0.0
	var measured_speed: float = weighted_speed / total_weight
	smoothed_speed = lerpf(smoothed_speed, measured_speed, 1.0 - exp(-delta / SPEED_SMOOTH_SECONDS))
	if smoothed_speed <= MOTION_THRESHOLD:
		_quiet_seconds += delta
		var target: float = clampf((_quiet_seconds - BLOOM_DELAY) / (BLOOM_FULL_TIME - BLOOM_DELAY), 0.0, 1.0)
		# Reopening starts from the surviving petals, never snaps them shut.
		_bloom = maxf(_bloom, target)
	else:
		_quiet_seconds = 0.0
		_bloom = maxf(0.0, _bloom - delta / BLOOM_DECAY_TIME)
	return clampf(_bloom, 0.0, 1.0)

func reset_session() -> void:
	smoothed_speed = 0.0
	_quiet_seconds = 0.0
	_bloom = 0.0
	_had_pose.fill(false)

func _pose_is_finite(pose: Transform3D) -> bool:
	return pose.origin.is_finite() and pose.basis.x.is_finite() and pose.basis.y.is_finite() and pose.basis.z.is_finite() and pose.basis.determinant() > 0.000001
