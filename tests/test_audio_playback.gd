extends SceneTree
## Run visibly with --xr-mode off and a real audio driver. Starts muted.
## This checks startup/teardown and device code paths, not listening quality.

const Driver = preload("res://scripts/audio/audio_driver.gd")
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	if DisplayServer.get_name() == "headless" or AudioServer.get_driver_name() == "Dummy":
		print("Audio playback fixture SKIPPED: requires visible display and real audio backend; no playback initialized.")
		quit(0)
		return
	var driver := Driver.new()
	driver.set_volume(0.0)
	root.add_child(driver)
	await create_timer(0.2).timeout
	var player: AudioStreamPlayer = driver.get_node_or_null("AmbientPlayer") as AudioStreamPlayer
	_check(player != null, "Real-backend player not constructed")
	if player != null:
		_check(player.playing, "Real-backend playback not started")
		_check(player.volume_linear == 0.0, "Fixture must have exact zero playback gain")
		_check(player.stream is AudioStreamWAV, "Placeholder stream absent")
	_check(driver.sample(0.1).source_available, "Playing source not available")
	var bus_index: int = AudioServer.get_bus_index(Driver.BUS_NAME)
	_check(bus_index >= 0, "Ambient bus missing")
	if bus_index >= 0:
		_check(AudioServer.get_bus_effect_instance(bus_index, 0) is AudioEffectSpectrumAnalyzerInstance, "Spectrum analyzer missing")
	driver.envelope_mode = Driver.EnvelopeMode.SPECTRUM
	_check(driver.sample(0.1).level > 0.0, "Muted spectrum did not retain synthetic visuals")
	driver.set_paused(true)
	await create_timer(0.1).timeout
	_check(player != null and player.stream_paused, "Pause not applied to player")
	_check(not driver.sample(0.1).source_available, "Paused source available")
	driver.reset_session()
	_check(driver.sample(0.0).level == 0.0, "Reset did not clear envelope")
	_check(player != null and player.stream_paused, "Reset did not preserve pause")
	driver.set_paused(false)
	await create_timer(0.1).timeout
	_check(driver.sample(0.1).source_available, "Resume did not restore source")
	driver.shutdown()
	driver.shutdown()
	_check(driver.get_node_or_null("AmbientPlayer") == null, "Shutdown left player node")
	_check(AudioServer.get_bus_index(Driver.BUS_NAME) == -1, "Shutdown left owned bus")
	await create_timer(0.1).timeout
	driver.queue_free()
	await process_frame
	print("Muted real-backend audio fixture: backend=", AudioServer.get_driver_name(), "; startup, analyzer, zero gain, pause/reset/resume and shutdown; failures=", failures, "; listening not tested")
	quit(1 if failures > 0 else 0)
