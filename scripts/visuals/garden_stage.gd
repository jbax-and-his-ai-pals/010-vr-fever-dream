class_name GardenStage
extends Node3D

const SHELL_RADIUS := 14.0
var _atmosphere_material: ShaderMaterial
var _shell: MeshInstance3D
var _last_head := Vector3.ZERO
var _has_head := false
var _flow_phase := Vector3.ZERO

func apply_frame(dream: DreamFrame, visitor: VisitorFrame = null) -> void:
	_atmosphere_material.set_shader_parameter("flow_time", dream.elapsed_seconds)
	_atmosphere_material.set_shader_parameter("intensity", dream.visual_intensity)
	_atmosphere_material.set_shader_parameter("visitor_position", visitor.head_transform.origin if visitor != null and visitor.head_valid else Vector3(0, 3, 0))
	if visitor != null and visitor.head_valid and visitor.head_transform.origin.is_finite():
		var head := visitor.head_transform.origin
		if _has_head and not visitor.motion_discontinuity:
			_flow_phase += (head - _last_head) * 0.08
			for axis in range(3):
				_flow_phase[axis] = fposmod(_flow_phase[axis], TAU)
		_last_head = head
		_has_head = true
		# An enclosing rendering surface, never a place the visitor can reach.
		_shell.global_position = head
		_atmosphere_material.set_shader_parameter("travel_phase", _flow_phase)
	else:
		_has_head = false
		_flow_phase = Vector3.ZERO
		_atmosphere_material.set_shader_parameter("travel_phase", _flow_phase)

func shift_origin(offset: Vector3) -> void:
	_last_head -= offset
	_shell.global_position -= offset

func _ready() -> void:
	var environment := WorldEnvironment.new()
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color(0.016, 0.019, 0.043)
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color(0.24, 0.35, 0.5)
	sky.ambient_light_energy = 0.7
	environment.environment = sky
	add_child(environment)
	var shell := MeshInstance3D.new()
	_shell = shell
	shell.name = "FluidBorderSphere"
	var sphere := SphereMesh.new()
	sphere.radius = SHELL_RADIUS
	sphere.height = SHELL_RADIUS * 2.0
	sphere.radial_segments = 96
	sphere.rings = 48
	shell.mesh = sphere
	shell.position.y = 3.0
	_atmosphere_material = ShaderMaterial.new()
	_atmosphere_material.shader = preload("res://shaders/atmosphere.gdshader")
	shell.material_override = _atmosphere_material
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shell)
