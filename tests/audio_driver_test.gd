extends SceneTree

const Driver = preload("res://scripts/audio/audio_driver.gd")
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var driver := Driver.new()
	root.add_child(driver)
	for index in 36000:
		var frame = driver.sample(1.0 / 60.0)
		for value in [frame.low, frame.mid, frame.high, frame.level]:
			_check(is_finite(value) and value >= 0.0 and value <= 1.0, "Envelope bounds")
	_check(not driver.sample(0.0).source_available, "Headless source must be unavailable")
	driver.reset_session()
	var baseline = driver.sample(0.2)
	driver.reset_session()
	driver.set_volume(0.0)
	var muted = driver.sample(0.2)
	_check(is_equal_approx(baseline.low, muted.low), "Mute changes visual envelope")
	_check(driver.volume == 0.0, "Volume did not mute")
	driver.set_paused(true)
	var paused = driver.sample(10.0)
	_check(is_equal_approx(paused.low, muted.low), "Pause advances envelope")
	driver.set_paused(false)
	driver.envelope_mode = Driver.EnvelopeMode.SPECTRUM
	_check(driver.sample(0.2).level > 0.0, "Missing analyzer did not fall back")
	driver.reset_session()
	_check(driver.sample(0.0).level == 0.0, "Reset left old envelope")
	driver.sample(NAN)
	_check(is_finite(driver.sample(INF).level), "Invalid delta corrupted envelope")
	var low_only: Vector4 = Driver.smooth_bands(Vector4.ZERO, Vector4(1.0, 0.0, 0.0, 0.5), 0.1, 0.32)
	_check(low_only.x > low_only.z and low_only.z == 0.0, "Low stimulus leaks into high band")
	var slow := Driver.new()
	var fast := Driver.new()
	for index in 300:
		slow.sample(1.0 / 30.0)
	for index in 1200:
		fast.sample(1.0 / 120.0)
	_check(absf(slow.sample(0.0).low - fast.sample(0.0).low) < 0.003, "Delta independence outside tolerance")
	var stream: AudioStreamWAV = Driver.make_placeholder_stream()
	var pcm: PackedByteArray = stream.data
	var peak: float = 0.0
	for index in pcm.size() / 2:
		var value: int = pcm.decode_s16(index * 2)
		peak = maxf(peak, absf(float(value) / 32767.0))
	_check(peak < 0.25, "Placeholder exceeds peak budget")
	_check(stream.loop_end == 352800 and stream.loop_begin == 0, "Loop endpoints")
	driver.shutdown()
	driver.shutdown()
	_check(not driver.sample(0.0).source_available, "Shutdown left an available source")
	print("Audio fixture: 600 s bounds, mute, pause, reset, fallback, low stimulus, timestep equivalence, PCM peak=", peak, "; failures=", failures)
	driver.queue_free()
	slow.free()
	fast.free()
	quit(1 if failures > 0 else 0)
