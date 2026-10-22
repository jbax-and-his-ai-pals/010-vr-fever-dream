extends SceneTree
## Uses ordinary Camera3D and simulated inputs. NEVER initializes XR.

const Rig = preload("res://scripts/input/xr_input.gd")
const Navigation = preload("res://scripts/navigation/xr_navigation.gd")
const Settings = preload("res://scripts/contracts/dream_settings.gd")
var failures: int = 0
var checks: int = 0
var teleport_count: int = 0
var opaque_at_commit: bool = false

class MockRig extends Rig:
	var focused: bool = true
	func tracking_usable() -> bool:
		return focused
	func is_session_focused() -> bool:
		return focused

class MockNavigation extends Navigation:
	var simulated_trigger: float = 0.0
	var simulated_stick: Vector2 = Vector2.ZERO
	var aim_valid: bool = true
	var simulated_target := Vector3(-3.0, 0.0, 2.0)
	func _controller_valid() -> bool:
		return true
	func _controller_stick() -> Vector2:
		return simulated_stick
	func _controller_trigger() -> float:
		return simulated_trigger
	func _update_target() -> void:
		target_valid = aim_valid
		target_position = simulated_target

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var rig := MockRig.new()
	root.add_child(rig)
	rig.camera = Camera3D.new()
	rig.add_child(rig.camera)
	rig.camera.position = Vector3(0.7, 1.65, -0.3)
	rig.position = Vector3(2.0, 0.0, -2.0)
	var nav := MockNavigation.new()
	root.add_child(nav)
	nav.setup(rig)
	var settings := Settings.new()
	nav.teleported.connect(func(_destination: Vector3):
		teleport_count += 1
		opaque_at_commit = nav._fade.visible and is_equal_approx(nav._fade_material.albedo_color.a, 1.0)
	)
	var original_head := rig.camera.global_position
	nav.advance(0.01, settings) # Arm only after released trigger/centered stick.
	nav.simulated_trigger = 1.0
	nav.advance(0.01, settings)
	_check(nav._aiming and nav.target_valid, "Trigger did not arm teleport")
	nav.simulated_trigger = 0.0
	nav.advance(0.01, settings)
	_check(nav.transition_active(), "Release did not queue fade")
	nav.advance(0.06, settings)
	_check(rig.camera.global_position.is_equal_approx(original_head), "Relocated before opaque fade")
	_check(nav._fade_material.albedo_color.a > 0.0 and nav._fade_material.albedo_color.a < 1.0, "Missing partial fade-out phase")
	nav.advance(1.0, settings) # Large timestep must still produce opaque movement frame.
	_check(teleport_count == 1 and opaque_at_commit, "Teleport signal was not exactly once under opaque fade")
	var arrived := rig.camera.global_position
	_check(Vector2(arrived.x, arrived.z).distance_to(Vector2(-3.0, 2.0)) < 0.00001, "Teleport ignored tracked head offset")
	_check(is_equal_approx(arrived.y, original_head.y), "Teleport altered head height")
	_check(nav._fade_material.albedo_color.a == 1.0, "Skipped fully opaque rendered frame")
	_check(not rig.sample().head_valid, "Post-move quiet interval did not suppress motion sampling")
	nav.advance(0.08, settings)
	_check(nav._fade_material.albedo_color.a > 0.0 and nav._fade_material.albedo_color.a < 1.0, "Missing partial fade-in phase")
	nav.advance(0.1, settings)
	_check(not nav._fade.visible and nav.transition_active(), "Quiet interval did not remain after fade")
	nav.advance(0.3, settings)
	_check(not nav.transition_active() and teleport_count == 1, "Transition never ended or emitted twice")
	# A queued teleport canceled by menu/focus loss must not execute on resume.
	nav.simulated_trigger = 1.0
	nav.advance(0.01, settings)
	nav.cancel_navigation()
	nav.advance(0.01, settings)
	_check(not nav._aiming, "Held trigger rearmed after menu cancel")
	nav.simulated_trigger = 0.0
	nav.advance(0.01, settings)
	_check(not nav.transition_active() and teleport_count == 1, "Release after menu cancel teleported")
	nav.simulated_trigger = 1.0
	nav.advance(0.01, settings)
	nav.simulated_trigger = 0.0
	nav.advance(0.01, settings)
	rig.focused = false
	nav.advance(0.2, settings)
	_check(not nav.transition_active() and teleport_count == 1, "Focus loss committed queued teleport")
	_check(not rig.sample().head_valid, "Focus loss left head sample valid")
	rig.focused = true
	rig._quiet_until_msec = 0
	_check(rig.sample().motion_discontinuity, "Focus recovery did not invalidate motion history")
	# An aim pose disappearing at release invalidates a previously valid target.
	nav.advance(0.01, settings)
	nav.simulated_trigger = 1.0
	nav.advance(0.01, settings)
	nav.aim_valid = false
	nav.simulated_trigger = 0.0
	nav.advance(0.01, settings)
	_check(not nav.transition_active(), "Lost aim pose committed stale target")
	nav.aim_valid = true
	# Snap around the physical head, exactly once per stick deflection.
	var before_snap := rig.camera.global_position
	nav.simulated_stick = Vector2(1.0, 0.0)
	nav.advance(0.01, settings)
	nav.advance(0.2, settings)
	_check(rig.camera.global_position.distance_to(before_snap) < 0.00001, "Snap moved offset physical head")
	var turned_basis := rig.global_basis
	nav.advance(0.2, settings)
	nav.advance(0.3, settings)
	nav.advance(0.01, settings)
	_check(not nav.transition_active() and rig.global_basis.is_equal_approx(turned_basis), "Held stick repeated snap")
	nav.cancel_navigation()
	nav.set_external_fade(1.0)
	_check(nav.transition_active() and nav._fade_material.albedo_color.a == 1.0, "External reset fade missing")
	nav.advance(1.0, settings)
	_check(rig.global_basis.is_equal_approx(turned_basis), "Reset fade allowed navigation")
	nav.set_external_fade(0.0)
	_check(not nav.transition_active() and not nav._fade.visible, "External fade never released")
	nav.reset_session()
	_check(not nav.transition_active() and not nav._aiming, "Reset retained pending navigation")
	# Simulate a runtime reference-space recenter after its signal. Keep the
	# previous world view, without overriding tracked camera/controller poses.
	rig._quiet_until_msec = 0
	rig.sample()
	var head_before_recenter := rig.camera.global_transform
	rig._on_pose_recentered()
	rig.camera.position += Vector3(0.9, 0.0, -0.7)
	rig.camera.rotation.y += 0.8
	var tracked_pose_after_recenter := rig.camera.transform
	var compensated_frame := rig.sample()
	var head_after_recenter := rig.camera.global_transform
	_check(Vector2(head_after_recenter.origin.x, head_after_recenter.origin.z).distance_to(Vector2(head_before_recenter.origin.x, head_before_recenter.origin.z)) < 0.00001, "Recenter moved world-facing head floor position")
	_check(head_after_recenter.basis.z.distance_to(head_before_recenter.basis.z) < 0.00001, "Recenter changed user-facing world heading")
	_check(rig.camera.transform.is_equal_approx(tracked_pose_after_recenter), "Recenter wrote runtime-owned camera pose")
	_check(rig.global_basis.y.distance_to(Vector3.UP) < 0.00001, "Recenter added pitch or roll")
	_check(compensated_frame.motion_discontinuity and not compensated_frame.head_valid, "Recenter retained old motion samples")
	var compensated_root := rig.global_transform
	rig.camera.position.x += 0.2
	rig.sample()
	_check(rig.global_transform.is_equal_approx(compensated_root), "Ordinary physical motion triggered recenter compensation")
	print("XR lifecycle fixture (ordinary camera; XR mode off): checks=", checks, "; failures=", failures)
	nav.queue_free()
	rig.queue_free()
	quit(1 if failures else 0)
