class_name XRPanel
extends Node3D

const PIXEL_SIZE := Vector2i(700, 760)
const WORLD_SIZE := Vector2(1.05, 1.14)
const MAX_RAY_DISTANCE := 5.0

var ui: DreamUI
var viewport: SubViewport
var head: Camera3D
var surface: MeshInstance3D
var cursor: MeshInstance3D
var ray_mesh: MeshInstance3D
var _pressed: bool = false
var _require_trigger_release: bool = false
var _last_pixel := Vector2.ZERO
var _ray_geometry: ImmediateMesh
var _wait_for_tracking: bool = false
var _placement_pending: bool = false

func setup(existing_ui: DreamUI, camera: Camera3D, wait_for_tracking: bool = false) -> void:
	ui = existing_ui
	head = camera
	_wait_for_tracking = wait_for_tracking
	viewport = SubViewport.new()
	viewport.size = PIXEL_SIZE
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.gui_disable_input = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	ui.reparent(viewport)
	ui.use_world_panel()
	surface = MeshInstance3D.new()
	var plane := QuadMesh.new()
	plane.size = WORLD_SIZE
	surface.mesh = plane
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.render_priority = 100
	material.albedo_texture = viewport.get_texture()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.material_override = material
	add_child(surface)
	cursor = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.008
	sphere.height = 0.016
	cursor.mesh = sphere
	var pointer_material := StandardMaterial3D.new()
	pointer_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pointer_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pointer_material.no_depth_test = true
	pointer_material.render_priority = 110
	pointer_material.albedo_color = Color(0.4, 1.0, 0.85)
	cursor.material_override = pointer_material
	add_child(cursor)
	cursor.hide()
	ray_mesh = MeshInstance3D.new()
	_ray_geometry = ImmediateMesh.new()
	ray_mesh.mesh = _ray_geometry
	ray_mesh.material_override = pointer_material
	add_child(ray_mesh)
	ray_mesh.top_level = true
	ray_mesh.global_transform = Transform3D.IDENTITY
	ui.open_changed.connect(_on_open_changed)
	_on_open_changed(ui.is_open())

func _on_open_changed(open: bool) -> void:
	visible = open
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if open else SubViewport.UPDATE_DISABLED
	if open:
		_require_trigger_release = true
		place_in_front_of_head()
	else:
		release_pointer()

func place_in_front_of_head() -> void:
	if _wait_for_tracking:
		# The camera starts at the origin before the runtime supplies a pose.
		# Opening/resetting must wait rather than anchor the menu to the floor.
		_placement_pending = true
		hide()
		release_pointer()
		return
	_place_from_pose(head.global_transform)

func update_head_pose(world_head: Transform3D, tracked: bool) -> void:
	if not tracked or not world_head.is_finite():
		_placement_pending = true
		hide()
		release_pointer()
		return
	if ui.is_open() and _placement_pending:
		_place_from_pose(world_head)
		_placement_pending = false
		show()

func _place_from_pose(world_head: Transform3D) -> void:
	# Horizontal direction removes roll/pitch; using tracked head height supports
	# standing and seated users without requiring a fixed floor-to-eye distance.
	var forward := -world_head.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	global_position = world_head.origin + forward * 1.35
	look_at(world_head.origin, Vector3.UP, true)
	rotation.x = 0.0
	rotation.z = 0.0

func ray_to_pixel(origin: Vector3, direction: Vector3) -> Variant:
	if not origin.is_finite() or not direction.is_finite() or direction.length_squared() < 0.000001:
		return null
	var inverse := global_transform.affine_inverse()
	var local_origin: Vector3 = inverse * origin
	var local_direction: Vector3 = inverse.basis * direction.normalized()
	if absf(local_direction.z) < 0.00001:
		return null
	var distance: float = -local_origin.z / local_direction.z
	if distance < 0.0 or distance > MAX_RAY_DISTANCE:
		return null
	var hit := local_origin + local_direction * distance
	if absf(hit.x) > WORLD_SIZE.x * 0.5 or absf(hit.y) > WORLD_SIZE.y * 0.5:
		return null
	return Vector2((hit.x / WORLD_SIZE.x + 0.5) * PIXEL_SIZE.x, (0.5 - hit.y / WORLD_SIZE.y) * PIXEL_SIZE.y)

func update_pointer(origin: Vector3, direction: Vector3, trigger_pressed: bool, valid: bool = true) -> void:
	if not trigger_pressed:
		_require_trigger_release = false
	if not valid or not ui.is_open() or not visible:
		release_pointer()
		return
	var pixel: Variant = ray_to_pixel(origin, direction)
	if pixel == null:
		release_pointer()
		return
	trigger_pressed = trigger_pressed and not _require_trigger_release
	var motion := InputEventMouseMotion.new()
	motion.position = pixel
	motion.global_position = pixel
	motion.relative = pixel - _last_pixel
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if _pressed else 0
	viewport.push_input(motion, true)
	_last_pixel = pixel
	if trigger_pressed != _pressed:
		_send_button(trigger_pressed)
	if not ui.is_open():
		release_pointer()
		return
	var local_hit := Vector3((pixel.x / PIXEL_SIZE.x - 0.5) * WORLD_SIZE.x, (0.5 - pixel.y / PIXEL_SIZE.y) * WORLD_SIZE.y, 0.005)
	cursor.position = local_hit
	cursor.show()
	_ray_geometry.clear_surfaces()
	_ray_geometry.surface_begin(Mesh.PRIMITIVE_LINES)
	_ray_geometry.surface_add_vertex(origin)
	_ray_geometry.surface_add_vertex(to_global(local_hit))
	_ray_geometry.surface_end()
	ray_mesh.show()

func _send_button(pressed: bool, canceled: bool = false) -> void:
	_pressed = pressed
	var event := InputEventMouseButton.new()
	event.position = _last_pixel
	event.global_position = _last_pixel
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	event.canceled = canceled
	viewport.push_input(event, true)

func release_pointer() -> void:
	if _pressed:
		_require_trigger_release = true
		_send_button(false, true)
	if viewport != null:
		# Cancel a press before releasing so tracking loss cannot activate a
		# destructive control such as Reset or Leave.
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(-100, -100)
		viewport.push_input(motion, true)
		_last_pixel = motion.position
	if cursor != null:
		cursor.hide()
	if ray_mesh != null:
		ray_mesh.hide()
