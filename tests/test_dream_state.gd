extends SceneTree

const Sampler = preload("res://scripts/dream/motion_sampler.gd")
const Director = preload("res://scripts/dream/dream_director.gd")
var _checks: int = 0
var _failures: int = 0

func _initialize() -> void:
	_test_bloom_timing()
	_test_invalid_and_discontinuous()
	_test_seated_weighting()
	_test_rotation_and_pause()
	_test_rate_equivalence()
	_test_director()
	for mood in ["silk", "coral", "aurora"]:
		var gradient: Gradient = load("res://resources/moods/%s.tres" % mood)
		_check(gradient != null and gradient.get_point_count() == 3, "mood palette loads: " + mood)
	print("Dream state: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)

func _test_bloom_timing() -> void:
	var sampler = Sampler.new()
	var visitor: VisitorFrame = VisitorFrame.new()
	var settings: DreamSettings = DreamSettings.new()
	var bloom: float = 0.0
	for tick in range(180):
		bloom = sampler.update(visitor, 1.0 / 60.0, settings)
	_check(bloom < 0.00001, "three second delay")
	for tick in range(150):
		bloom = sampler.update(visitor, 1.0 / 60.0, settings)
	_check(absf(bloom - 0.5) < 0.00001, "half bloom at 5.5 seconds")
	for tick in range(150):
		bloom = sampler.update(visitor, 1.0 / 60.0, settings)
	_check(absf(bloom - 1.0) < 0.00001, "full bloom at eight seconds")
	for tick in range(150):
		visitor.head_transform.origin.x += 1.0 / 60.0
		bloom = sampler.update(visitor, 1.0 / 60.0, settings)
	_check(bloom == 0.0, "renewed motion closes bloom after speed smoothing plus two seconds")
	sampler.reset_session()
	_check(sampler.update(visitor, 0.0, settings) == 0.0 and sampler.smoothed_speed == 0.0, "reset clears envelope and speed")

func _test_invalid_and_discontinuous() -> void:
	var sampler = Sampler.new()
	var visitor: VisitorFrame = VisitorFrame.new()
	var settings: DreamSettings = DreamSettings.new()
	for tick in range(480):
		visitor.left_hand_transform.origin.x = float(tick) * 1000.0
		sampler.update(visitor, 1.0 / 60.0, settings)
	_check(sampler.update(visitor, 0.0, settings) > 0.999, "invalid moving hands do not block bloom")
	visitor.motion_discontinuity = true
	visitor.head_transform.origin.x = 1000.0
	_check(sampler.update(visitor, 1.0 / 60.0, settings) == 0.0, "discontinuity clears bloom immediately")
	visitor.motion_discontinuity = false
	sampler.update(visitor, 1.0 / 60.0, settings)
	_check(sampler.smoothed_speed == 0.0, "discontinuous jump creates no speed spike")
	visitor.left_hand_valid = true
	sampler.update(visitor, 1.0 / 60.0, settings)
	_check(sampler.smoothed_speed == 0.0, "tracking recovery establishes baseline without spike")
	visitor.head_valid = false
	visitor.left_hand_valid = false
	_check(sampler.update(visitor, 8.0, settings) == 0.0, "no valid tracking cannot bloom")
	visitor.head_valid = true
	visitor.head_transform.origin.x = NAN
	_check(sampler.update(visitor, 8.0, settings) == 0.0, "nonfinite pose rejected")

func _test_seated_weighting() -> void:
	var standing = Sampler.new()
	var seated = Sampler.new()
	var visitor: VisitorFrame = VisitorFrame.new()
	visitor.left_hand_valid = true
	visitor.right_hand_valid = true
	var normal_settings: DreamSettings = DreamSettings.new()
	var seated_settings: DreamSettings = DreamSettings.new()
	seated_settings.seated_mode = true
	var standing_bloom: float = 0.0
	var seated_bloom: float = 0.0
	for tick in range(600):
		visitor.left_hand_transform.origin.x = tick * 0.3 / 60.0
		visitor.right_hand_transform.origin.x = tick * 0.3 / 60.0
		standing_bloom = standing.update(visitor, 1.0 / 60.0, normal_settings)
		seated_bloom = seated.update(visitor, 1.0 / 60.0, seated_settings)
	_check(standing_bloom == 0.0 and seated_bloom > 0.999, "seated weighting tolerates hand motion")

func _test_rate_equivalence() -> void:
	var baseline: PackedFloat64Array = _simulate(60)
	for rate in [30, 90, 120]:
		var result: PackedFloat64Array = _simulate(rate)
		_check(absf(result[0] - baseline[0]) < 0.025, "natural tremor bloom equivalent at %d Hz" % rate)
		_check(absf(result[1] - baseline[1]) < 0.025, "decay equivalent at %d Hz" % rate)

func _test_rotation_and_pause() -> void:
	var sampler = Sampler.new()
	var visitor: VisitorFrame = VisitorFrame.new()
	var settings: DreamSettings = DreamSettings.new()
	var bloom: float = 0.0
	for tick in range(600):
		visitor.head_transform.basis = Basis(Vector3.UP, float(tick) / 60.0)
		bloom = sampler.update(visitor, 1.0 / 60.0, settings)
	_check(bloom == 0.0, "turning head contributes angular speed")
	sampler.reset_session()
	sampler.update(visitor, 1.0 / 60.0, settings)
	visitor.head_transform.origin.x = 500.0
	sampler.update(visitor, 0.0, settings)
	sampler.update(visitor, 1.0 / 60.0, settings)
	_check(sampler.smoothed_speed == 0.0, "paused movement does not create a resume spike")
	visitor.head_transform.basis = Basis(Vector3(-1.0, 0.0, 0.0), Vector3.UP, Vector3.BACK)
	_check(sampler.update(visitor, 8.0, settings) == 0.0, "mirrored tracking basis rejected")

func _simulate(rate: int) -> PackedFloat64Array:
	var sampler = Sampler.new()
	var visitor: VisitorFrame = VisitorFrame.new()
	visitor.left_hand_valid = true
	visitor.right_hand_valid = true
	var settings: DreamSettings = DreamSettings.new()
	var bloom: float = 0.0
	for tick in range(rate * 7):
		var seconds: float = float(tick) / rate
		visitor.head_transform.origin.y = sin(seconds * TAU * 0.3) * 0.006
		visitor.left_hand_transform.origin.x = sin(seconds * TAU * 3.0) * 0.002
		visitor.right_hand_transform.origin.x = cos(seconds * TAU * 3.0) * 0.002
		bloom = sampler.update(visitor, 1.0 / rate, settings)
	var quiet_bloom: float = bloom
	for tick in range(rate):
		visitor.head_transform.origin.x += 1.0 / rate
		bloom = sampler.update(visitor, 1.0 / rate, settings)
	return PackedFloat64Array([quiet_bloom, bloom])

func _test_director() -> void:
	var director = Director.new()
	var settings: DreamSettings = DreamSettings.new()
	var frame: DreamFrame = director.step(89.0, 0.2, settings)
	_check(frame.mood_from == 0 and frame.mood_to == 0, "Silk dwell")
	frame = director.step(1.0, 0.2, settings)
	_check(frame.mood_from == 0 and frame.mood_to == 1 and frame.mood_blend == 0.0, "transition starts at90")
	frame = director.step(15.0, 0.2, settings)
	_check(absf(frame.mood_blend - 0.5) < 0.00001, "transition midpoint at105")
	frame = director.step(15.0, 0.2, settings)
	_check(frame.mood_from == 1 and frame.mood_to == 1, "Coral dwell starts at120")
	frame = director.step(120.0, 0.2, settings)
	_check(frame.mood_from == 2 and frame.mood_to == 2, "Aurora dwell starts at240")
	frame = director.step(120.0, 0.2, settings)
	_check(frame.mood_from == 0 and frame.mood_to == 0, "cycle returns to Silk at360")
	director.reset_session()
	frame = director.step(0.0, 0.0, settings)
	_check(frame.elapsed_seconds == 0.0 and frame.mood_from == 0 and frame.stillness == 0.0, "director reset")
	frame = director.step(-10.0, 2.0, settings)
	_check(frame.elapsed_seconds == 0.0 and frame.stillness == 1.0, "negative delta ignored and normalized bloom")
	for rate in [30, 60, 90, 120]:
		director.reset_session()
		for tick in range(rate * 105):
			frame = director.step(1.0 / rate, 0.0, settings)
		_check(frame.mood_from == 0 and frame.mood_to == 1 and absf(frame.mood_blend - 0.5) < 0.00001, "mood timing equivalent at %d Hz" % rate)

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + label)
