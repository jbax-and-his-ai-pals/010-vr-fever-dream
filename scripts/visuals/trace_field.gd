class_name TraceField
extends Node3D

const STROKE_CAP: int = 256
const CURL_CAP: int = 64
const LIFETIME: float = 90.0
const MIN_DISTANCE: float = 0.12
const MAX_DISTANCE: float = 0.35

var strokes: MultiMeshInstance3D
var curls: MultiMeshInstance3D
var _material: ShaderMaterial
var _curl_material: ShaderMaterial
var _born := PackedFloat32Array()
var _curl_for := PackedInt32Array()
var _curl_owners := PackedInt32Array()
var _positions := PackedVector3Array()
var _last: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _valid: Array[bool] = [false, false, false]
var _source_times: Array[float] = [0.0, 0.0, 0.0]
var _clock: float = 0.0
var _cursor: int = 0
var _deposits: int = 0

func _ready() -> void:
	_born.resize(STROKE_CAP)
	_born.fill(-1000.0)
	_curl_for.resize(STROKE_CAP)
	_curl_for.fill(-1)
	_curl_owners.resize(CURL_CAP)
	_curl_owners.fill(-1)
	_positions.resize(STROKE_CAP)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.012
	mesh.bottom_radius = 0.008
	mesh.height = 1.0
	mesh.radial_segments = 6
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/trace.gdshader")
	strokes = _make_pool(mesh, STROKE_CAP, _material)
	_curl_material = ShaderMaterial.new()
	_curl_material.shader = _material.shader
	_curl_material.set_shader_parameter("is_curl", true)
	curls = _make_pool(_curl_mesh(), CURL_CAP, _curl_material)

func _make_pool(mesh: Mesh, count: int, material: Material) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	var pool := MultiMesh.new()
	pool.transform_format = MultiMesh.TRANSFORM_3D
	pool.use_custom_data = true
	pool.mesh = mesh
	pool.instance_count = count
	pool.custom_aabb = AABB(Vector3(-10, -1, -10), Vector3(20, 8, 20))
	instance.multimesh = pool
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	for i in count:
		pool.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
		pool.set_instance_custom_data(i, Color(-1000.0, 0.0, 0.0, 0.0))
	return instance

func _curl_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 24:
		var t0 := float(i) / 24.0
		var t1 := float(i + 1) / 24.0
		var a := Vector3(cos(t0 * TAU * 1.6) * 0.16 * t0, t0 * 0.45, sin(t0 * TAU * 1.6) * 0.16 * t0)
		var b := Vector3(cos(t1 * TAU * 1.6) * 0.16 * t1, t1 * 0.45, sin(t1 * TAU * 1.6) * 0.16 * t1)
		var width := Vector3(0.015, 0.0, 0.0)
		for point: Vector3 in [a - width, b - width, a + width, a + width, b - width, b + width]:
			tool.add_vertex(point)
	tool.generate_normals()
	return tool.commit()

func update_frame(visitor: VisitorFrame, dream: DreamFrame, delta: float) -> void:
	_clock += maxf(delta, 0.0)
	if visitor.motion_discontinuity:
		_valid.fill(false)
	_sample_source(0, Vector3(visitor.head_transform.origin.x, 0.035, visitor.head_transform.origin.z), visitor.head_valid)
	_sample_source(1, visitor.left_hand_transform.origin, visitor.left_hand_valid and visitor.left_hand_active)
	_sample_source(2, visitor.right_hand_transform.origin, visitor.right_hand_valid and visitor.right_hand_active)
	for i in STROKE_CAP:
		var age := _clock - _born[i]
		if _born[i] < 0.0:
			continue
		if age >= LIFETIME:
			_remove_slot(i)
		elif age >= 35.0 and i % 4 == 0 and _curl_for[i] == -1:
			_mature(i)
	for material: ShaderMaterial in [_material, _curl_material]:
		material.set_shader_parameter("dream_time", _clock)
		material.set_shader_parameter("intensity", dream.visual_intensity)
		material.set_shader_parameter("mood_from", dream.mood_from)
		material.set_shader_parameter("mood_to", dream.mood_to)
		material.set_shader_parameter("mood_blend", dream.mood_blend)

func _sample_source(source: int, point: Vector3, valid: bool) -> void:
	if not valid:
		_valid[source] = false
		return
	if not _valid[source]:
		_last[source] = point
		_source_times[source] = _clock
		_valid[source] = true
		return
	var distance := point.distance_to(_last[source])
	if distance > MAX_DISTANCE:
		_last[source] = point
		_source_times[source] = _clock
	elif distance >= MIN_DISTANCE and _clock - _source_times[source] >= 0.1:
		_deposit(_last[source], point, source)
		_last[source] = point
		_source_times[source] = _clock

func _deposit(start: Vector3, end: Vector3, source: int) -> void:
	var index := _cursor
	_cursor = (_cursor + 1) % STROKE_CAP
	_remove_slot(index)
	var direction := end - start
	var length := maxf(direction.length(), 0.02)
	var y := direction.normalized() if direction.length() > 0.001 else Vector3.UP
	var reference := Vector3.RIGHT if absf(y.dot(Vector3.UP)) > 0.95 else Vector3.UP
	var x := reference.cross(y).normalized()
	var z := x.cross(y).normalized()
	var basis := Basis(x, y * length, z)
	_positions[index] = (start + end) * 0.5
	_born[index] = _clock
	strokes.multimesh.set_instance_transform(index, Transform3D(basis, _positions[index]))
	strokes.multimesh.set_instance_custom_data(index, Color(_clock, float(source) / 2.0, 1.0, 1.0))
	_deposits += 1

func _remove_slot(index: int) -> void:
	_born[index] = -1000.0
	strokes.multimesh.set_instance_custom_data(index, Color(-1000.0, 0.0, 0.0, 0.0))
	if _curl_for[index] != -1:
		var curl := _curl_for[index]
		curls.multimesh.set_instance_custom_data(curl, Color(-1000.0, 0.0, 0.0, 0.0))
		_curl_owners[curl] = -1
		_curl_for[index] = -1

func _mature(index: int) -> void:
	var curl := _curl_owners.find(-1)
	if curl < 0:
		return
	_curl_owners[curl] = index
	_curl_for[index] = curl
	curls.multimesh.set_instance_transform(curl, Transform3D(Basis.IDENTITY, _positions[index]))
	curls.multimesh.set_instance_custom_data(curl, Color(_born[index], 0.6, 1.0, 1.0))

func add_arrival_seed(position: Vector3) -> void:
	var floor_point := Vector3(position.x, 0.035, position.z)
	_deposit(floor_point, floor_point + Vector3(0.0, 0.06, 0.0), 0)
	_valid.fill(false)

func reset_session() -> void:
	if strokes:
		for i in STROKE_CAP:
			_remove_slot(i)
	_clock = 0.0
	_cursor = 0
	_deposits = 0
	_valid.fill(false)

func get_counts() -> Vector2i:
	var live := 0
	var mature := 0
	for born: float in _born:
		if born >= 0.0:
			live += 1
	for owner: int in _curl_owners:
		if owner >= 0:
			mature += 1
	return Vector2i(live, mature)

func get_total_deposits() -> int:
	return _deposits
