extends SceneTree
## Isolated ribbon check. Always invoke with --xr-mode off.

var field: Node3D
var visitor := VisitorFrame.new()
var dream := DreamFrame.new()
var audio := AudioFrame.new()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	field = load("res://scripts/visuals/ribbon_field.gd").new()
	world.add_child(field)
	assert(field.get_instance_count() == 16)
	field.set_quality(DreamSettings.Quality.LOW)
	assert(field.get_instance_count() == 10)
	field.set_quality(DreamSettings.Quality.DEFAULT)
	visitor.head_transform.origin = Vector3(0.0, 1.65, 3.8)
	visitor.left_hand_valid = true
	visitor.left_hand_active = true
	visitor.left_hand_transform.origin = Vector3(-0.45, 1.3, 2.4)
	for frame in range(60):
		dream.elapsed_seconds = frame / 60.0
		field.apply_frame(visitor, dream, audio)
	assert(field._left_strength > 0.99)
	var last_valid: Vector3 = field._left_position
	visitor.left_hand_valid = false
	visitor.left_hand_transform.origin = Vector3(1000.0, 1000.0, 1000.0)
	for frame in range(60, 180):
		dream.elapsed_seconds = frame / 60.0
		field.apply_frame(visitor, dream, audio)
	assert(field._left_position == last_valid)
	assert(field._left_strength < 0.01)
	assert(field.get_instance_count() == 16)
	field.reset_session()
	assert(field._left_strength == 0.0)
	assert(field._right_strength == 0.0)
	assert(field._last_time == -1.0)
	print("CLOUD CHECKS PASS: 16/10 instances, activation, invalid pose retention, release, reset")
	if "--ribbon-render" not in OS.get_cmdline_user_args():
		quit(0)
		return
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0.0, 1.65, 3.8)
	camera.look_at(Vector3(0.0, 1.8, -0.6))
	camera.fov = 76.0
	root.size = Vector2i(960, 600)
	root.get_viewport().transparent_bg = false
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.012, 0.018, 0.045)
	environment.environment = settings
	world.add_child(environment)
	visitor.left_hand_active = false
	visitor.left_hand_valid = false
	for mood in range(3):
		dream.mood_from = mood
		dream.mood_to = mood
		dream.stillness = 0.0
		dream.elapsed_seconds = 14.0
		field.apply_frame(visitor, dream, audio)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/validation/ribbon_mood_%d.png" % mood)
	dream.stillness = 1.0
	field.apply_frame(visitor, dream, audio)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/validation/ribbon_bloom.png")
	print("RIBBON RENDER CAPTURES SAVED")
	quit(0)
