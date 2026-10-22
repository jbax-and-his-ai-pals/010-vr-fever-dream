class_name RibbonField
extends Node3D
## Sparse volumetric silhouettes; smooth cloud deformation happens on the GPU.

@export_range(0.2, 2.0) var influence_radius: float = 1.25
@export_range(0.0, 0.6) var bend_cap: float = 0.6
@export_range(0.1, 3.0) var release_seconds: float = 1.5

const DEFAULT_COUNT := 16
const LOW_COUNT := 10
const PALETTES := [
	[Color(0.075, 0.18, 0.38), Color(0.17, 0.8, 0.88), Color(0.79, 0.64, 1.0)],
	[Color(0.22, 0.07, 0.36), Color(1.0, 0.45, 0.37), Color(1.0, 0.8, 0.47)],
	[Color(0.035, 0.3, 0.32), Color(0.28, 0.92, 0.75), Color(1.0, 0.62, 0.85)],
]

var _material: ShaderMaterial
var _field: MultiMeshInstance3D
var _left_position := Vector3.ZERO
var _right_position := Vector3.ZERO
var _left_strength: float = 0.0
var _right_strength: float = 0.0
var _last_time: float = -1.0
var _quality: int = DreamSettings.Quality.DEFAULT
var _homes: Array[Transform3D] = []
var _initial_homes: Array[Transform3D] = []
var _current: Array[Transform3D] = []
var _custom: Array[Color] = []
var _responses := PackedFloat32Array()

func _ready() -> void:
	_build_field()

func _build_field() -> void:
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/ribbon.gdshader")
	var instancing := MultiMesh.new()
	instancing.transform_format = MultiMesh.TRANSFORM_3D
	instancing.use_custom_data = true
	var shell := SphereMesh.new()
	shell.radius = 1.0
	shell.height = 2.0
	shell.radial_segments = 32
	shell.rings = 20
	instancing.mesh = shell
	instancing.instance_count = DEFAULT_COUNT
	_responses.resize(DEFAULT_COUNT)
	# The shapes drift and deform without touching their instance transforms.
	instancing.custom_aabb = AABB(Vector3(-13, -3, -13), Vector3(26, 13, 26))
	for index in range(DEFAULT_COUNT):
		var angle: float = index * 2.39996323
		var radius: float = 2.8 + 5.0 * sqrt(float(index) / DEFAULT_COUNT)
		var center := Vector3(cos(angle) * radius, -7.0 + 17.0 * _hash(index + 8), sin(angle) * radius)
		# A few incomplete shapes hang near the starting route, with an open centre.
		if index < 3:
			center = [Vector3(-1.8, 1.9, 0.7), Vector3(2.15, 2.8, -1.4), Vector3(-0.4, 4.3, -3.6)][index]
		var size: float = 0.68 + 0.55 * _hash(index + 22)
		var shape_scale := Vector3(size * (1.15 + 0.65 * _hash(index + 44)), size * (0.65 + 0.6 * _hash(index + 11)), size)
		var shape_basis := Basis.from_euler(Vector3(_hash(index + 70), angle, _hash(index + 90))) * Basis.from_scale(shape_scale)
		var home := Transform3D(shape_basis, center)
		_homes.append(home)
		_current.append(home)
		instancing.set_instance_transform(index, home)
		var data := Color(_hash(index + 17), _hash(index + 55), _hash(index + 91), 0.0)
		_custom.append(data)
		instancing.set_instance_custom_data(index, data)
	_initial_homes.assign(_homes)
	_field = MultiMeshInstance3D.new()
	_field.name = "DriftingCloudForms"
	_field.multimesh = instancing
	_field.material_override = _material
	_field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_field)
	set_quality(_quality)
	reset_session()

func _hash(index: int) -> float:
	return fposmod(sin(float(index) * 127.1) * 43758.5453, 1.0)

func apply_frame(visitor: VisitorFrame, dream: DreamFrame, audio: AudioFrame) -> void:
	if _material == null:
		return
	var elapsed: float = maxf(dream.elapsed_seconds, 0.0)
	var delta: float = clampf(elapsed - _last_time, 0.0, 0.1) if _last_time >= 0.0 else 1.0 / 60.0
	_last_time = elapsed
	_stream_around(visitor)
	_update_avoidance(visitor, delta)
	if visitor.motion_discontinuity:
		_left_strength = 0.0
		_right_strength = 0.0
	var left_on := visitor.left_hand_valid and visitor.left_hand_active
	var right_on := visitor.right_hand_valid and visitor.right_hand_active
	if left_on:
		_left_position = visitor.left_hand_transform.origin
	if right_on:
		_right_position = visitor.right_hand_transform.origin
	# Inactive or invalid hands keep their last good position while releasing.
	var release_rate: float = 4.6 / maxf(release_seconds, 0.1)
	_left_strength = lerpf(_left_strength, 1.0 if left_on else 0.0, 1.0 - exp(-delta * (18.0 if left_on else release_rate)))
	_right_strength = lerpf(_right_strength, 1.0 if right_on else 0.0, 1.0 - exp(-delta * (18.0 if right_on else release_rate)))
	var mood_a: int = clampi(dream.mood_from, 0, 2)
	var mood_b: int = clampi(dream.mood_to, 0, 2)
	var blend: float = clampf(dream.mood_blend, 0.0, 1.0)
	for channel in range(3):
		_material.set_shader_parameter(["root_color", "body_color", "tip_color"][channel], PALETTES[mood_a][channel].lerp(PALETTES[mood_b][channel], blend))
	_material.set_shader_parameter("shape_mood", lerpf(float(mood_a), float(mood_b), blend))
	_material.set_shader_parameter("dream_time", elapsed)
	_material.set_shader_parameter("intensity", clampf(dream.visual_intensity, 0.0, 1.0))
	_material.set_shader_parameter("stillness", clampf(dream.stillness, 0.0, 1.0))
	_material.set_shader_parameter("visitor_position", visitor.head_transform.origin)
	_material.set_shader_parameter("hand_left", _left_position)
	_material.set_shader_parameter("hand_right", _right_position)
	_material.set_shader_parameter("hand_strength", Vector2(_left_strength, _right_strength))
	_material.set_shader_parameter("influence_radius", clampf(influence_radius, 0.2, 2.0))
	_material.set_shader_parameter("bend_cap", clampf(bend_cap, 0.0, 0.6))
	_material.set_shader_parameter("audio_bands", Vector3(clampf(audio.low, 0.0, 1.0), clampf(audio.mid, 0.0, 1.0), clampf(audio.high, 0.0, 1.0)))

func set_quality(tier: int) -> void:
	_quality = tier
	if _field != null:
		_field.multimesh.visible_instance_count = LOW_COUNT if tier == DreamSettings.Quality.LOW else DEFAULT_COUNT

func get_instance_count() -> int:
	return _field.multimesh.visible_instance_count if _field != null else 0

func reset_session() -> void:
	_homes.assign(_initial_homes)
	_current.assign(_homes)
	if _field != null:
		for index in range(_homes.size()):
			_field.multimesh.set_instance_transform(index, _homes[index])
			_responses[index] = 0.0
			_set_response(index, 0.0)
	_left_strength = 0.0
	_right_strength = 0.0
	_left_position = Vector3.ZERO
	_right_position = Vector3.ZERO
	_last_time = -1.0
	if _material != null:
		_material.set_shader_parameter("hand_strength", Vector2.ZERO)
		_material.set_shader_parameter("stillness", 0.0)
		_material.set_shader_parameter("dream_time", 0.0)

func _set_response(index: int, value: float) -> void:
	var data := _custom[index]
	data.a = value
	_custom[index] = data
	_field.multimesh.set_instance_custom_data(index, data)

func _stream_around(visitor: VisitorFrame) -> void:
	if not visitor.head_valid or not visitor.head_transform.origin.is_finite():
		return
	var viewer := to_local(visitor.head_transform.origin)
	# Reuse a fixed pool only beyond the visual fade; forms never wrap nearby.
	for index in range(_homes.size()):
		var difference := _homes[index].origin - viewer
		var shift := Vector3.ZERO
		for axis in range(3):
			shift[axis] = -floor((difference[axis] + 12.0) / 24.0) * 24.0
		if shift != Vector3.ZERO:
			_homes[index].origin += shift
			var transform := _current[index]
			transform.origin += shift
			_current[index] = transform
			_field.multimesh.set_instance_transform(index, transform)
			_responses[index] = 0.0
			_set_response(index, 0.0)
	_field.multimesh.custom_aabb = AABB(viewer - Vector3.ONE * 20.0, Vector3.ONE * 40.0)

func shift_origin(offset: Vector3) -> void:
	for index in range(_homes.size()):
		_homes[index].origin -= offset
		var transform := _current[index]
		transform.origin -= offset
		_current[index] = transform
		_field.multimesh.set_instance_transform(index, transform)

func _update_avoidance(visitor: VisitorFrame, delta: float) -> void:
	var viewer := to_local(visitor.head_transform.origin)
	var valid := visitor.head_valid and viewer.is_finite()
	for index in range(_homes.size()):
		var home := _homes[index]
		var transform := _current[index]
		# Slow recovery leaves a temporary pocket in the fluid after passing.
		var candidate := transform.origin.lerp(home.origin, 1.0 - exp(-delta * 0.35))
		var response := 0.0
		if valid:
			var away := candidate - viewer
			var distance_to_viewer := away.length()
			# Include broad shader folds/drift and hands in the shape's envelope.
			var radius := maxf(home.basis.x.length(), maxf(home.basis.y.length(), home.basis.z.length())) * 1.65 + 0.85
			var clearance := radius + 0.9
			response = 1.0 - smoothstep(clearance, clearance + 3.0, distance_to_viewer)
			var direction := away / distance_to_viewer if distance_to_viewer > 0.001 else Vector3(cos(index * 2.4), 0.25, sin(index * 2.4)).normalized()
			candidate += direction * response * delta * 1.4
			# Project out of the personal-space envelope, including fast approaches.
			if candidate.distance_to(viewer) < clearance:
				candidate = viewer + direction * clearance
		transform.origin = candidate
		_current[index] = transform
		_field.multimesh.set_instance_transform(index, transform)
		_responses[index] = lerpf(_responses[index], response, 1.0 - exp(-delta * (4.0 if response > _responses[index] else 0.65)))
		_set_response(index, _responses[index])

