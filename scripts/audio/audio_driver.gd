class_name AudioDriver
extends Node
## Original generated ambient loop plus repeatable, volume-independent envelopes.
## The composition root calls sample(); this node never advances visual time itself.

const Frame = preload("res://scripts/contracts/audio_frame.gd")
const BUS_NAME: StringName = &"DreamAmbient"
const LOOP_SECONDS: float = 16.0
const SAMPLE_RATE: int = 22050
enum EnvelopeMode { SYNTHETIC, SPECTRUM }

@export var envelope_mode: EnvelopeMode = EnvelopeMode.SYNTHETIC
@export_range(0.01, 2.0) var smoothing_seconds: float = 0.32
@export_range(0.0, 1.0) var volume: float = 0.5
@export var playback_enabled: bool = true

var _elapsed: float = 0.0
var _smoothed: Vector4 = Vector4.ZERO
var _paused: bool = false
var _player: AudioStreamPlayer
var _analyzer: AudioEffectSpectrumAnalyzerInstance
var _owned_bus: bool = false


func _ready() -> void:
	# Dummy audio in headless mode needs no PCM allocation or playback.
	if not playback_enabled or DisplayServer.get_name() == "headless" or AudioServer.get_driver_name() == "Dummy":
		return
	var bus_index: int = AudioServer.get_bus_index(BUS_NAME)
	if bus_index < 0:
		AudioServer.add_bus()
		bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, BUS_NAME)
		AudioServer.set_bus_send(bus_index, &"Master")
		var effect := AudioEffectSpectrumAnalyzer.new()
		effect.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_2048
		AudioServer.add_bus_effect(bus_index, effect)
		_owned_bus = true
	for effect_index in AudioServer.get_bus_effect_count(bus_index):
		if AudioServer.get_bus_effect(bus_index, effect_index) is AudioEffectSpectrumAnalyzer:
			_analyzer = AudioServer.get_bus_effect_instance(bus_index, effect_index) as AudioEffectSpectrumAnalyzerInstance
			break
	_player = AudioStreamPlayer.new()
	_player.name = "AmbientPlayer"
	_player.bus = BUS_NAME
	_player.stream = make_placeholder_stream()
	add_child(_player)
	set_volume(volume)
	_player.play()
	_player.stream_paused = _paused


func sample(delta: float) -> AudioFrame:
	var frame := Frame.new()
	if not _paused:
		var step: float = maxf(delta, 0.0) if is_finite(delta) else 0.0
		_elapsed = fmod(_elapsed + step, LOOP_SECONDS)
		var target: Vector4 = synthetic_bands(_elapsed)
		# Missing analyzer, dummy backend, pause, or mute never freezes the dream.
		if envelope_mode == EnvelopeMode.SPECTRUM and _analyzer != null and volume > 0.0001:
			target = _spectrum_bands()
		_smoothed = smooth_bands(_smoothed, target, step, smoothing_seconds)
	frame.low = _smoothed.x
	frame.mid = _smoothed.y
	frame.high = _smoothed.z
	frame.level = _smoothed.w
	frame.source_available = is_instance_valid(_player) and _player.playing and not _paused
	return frame


func reset_session() -> void:
	_elapsed = 0.0
	_smoothed = Vector4.ZERO
	if is_instance_valid(_player):
		_player.play(0.0)
		_player.stream_paused = _paused


func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0) if is_finite(value) else 0.0
	if is_instance_valid(_player):
		_player.volume_linear = volume
		# Zero means exact zero gain without muting a shared bus.


func set_paused(value: bool) -> void:
	_paused = value
	if is_instance_valid(_player):
		_player.stream_paused = value


static func synthetic_bands(seconds: float) -> Vector4:
	var phase: float = TAU * seconds / LOOP_SECONDS
	var low: float = 0.32 + 0.23 * (0.5 + 0.5 * sin(phase))
	var mid: float = 0.20 + 0.24 * (0.5 + 0.5 * sin(phase * 2.0 + 1.1))
	var high: float = 0.10 + 0.17 * (0.5 + 0.5 * sin(phase * 3.0 + 2.0))
	return Vector4(low, mid, high, low * 0.5 + mid * 0.35 + high * 0.15)


static func smooth_bands(previous: Vector4, target: Vector4, delta: float, duration: float) -> Vector4:
	var weight: float = 1.0 - exp(-maxf(delta, 0.0) / maxf(duration, 0.001))
	var bounded := Vector4(clampf(target.x, 0.0, 1.0), clampf(target.y, 0.0, 1.0), clampf(target.z, 0.0, 1.0), clampf(target.w, 0.0, 1.0))
	return previous.lerp(bounded, weight)


func _spectrum_bands() -> Vector4:
	# Peak magnitudes of the quiet original tones, normalized before smoothing.
	var low: float = _band_energy(40.0, 250.0, 0.07)
	var mid: float = _band_energy(250.0, 2000.0, 0.045)
	var high: float = _band_energy(2000.0, 8000.0, 0.018)
	return Vector4(low, mid, high, clampf(low * 0.5 + mid * 0.35 + high * 0.15, 0.0, 1.0))


func _band_energy(from_hz: float, to_hz: float, reference: float) -> float:
	var magnitude: Vector2 = _analyzer.get_magnitude_for_frequency_range(from_hz, to_hz)
	return clampf(maxf(magnitude.x, magnitude.y) / (reference * maxf(volume, 0.0001)), 0.0, 1.0)


static func make_placeholder_stream() -> AudioStreamWAV:
	# 16 s mono PCM, harmonic tones and periodic modulation. Integer cycles at
	# both carrier and envelope frequencies make the seam continuous.
	var count: int = int(LOOP_SECONDS * SAMPLE_RATE)
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	for index in count:
		var seconds: float = float(index) / SAMPLE_RATE
		var bands: Vector4 = synthetic_bands(seconds)
		var wave: float = bands.x * (0.20 * sin(TAU * 110.0 * seconds) + 0.08 * sin(TAU * 220.0 * seconds))
		wave += bands.y * (0.10 * sin(TAU * 330.0 * seconds) + 0.055 * sin(TAU * 880.0 * seconds))
		wave += bands.z * 0.06 * sin(TAU * 2640.0 * seconds)
		var signed_sample: int = int(round(wave * 32767.0))
		pcm.encode_u16(index * 2, signed_sample & 0xffff)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	return stream


func shutdown() -> void:
	# Call before quitting and allow the audio server to process its queued
	# playback stop. _exit_tree remains an idempotent final safeguard.
	if is_instance_valid(_player):
		var retiring_player: AudioStreamPlayer = _player
		_player = null
		retiring_player.stop()
		# Release the player's playback/PCM references before bus teardown.
		# Looping WAV playback can otherwise survive until server shutdown.
		retiring_player.stream = null
		retiring_player.free()
	_analyzer = null
	if _owned_bus:
		var bus_index: int = AudioServer.get_bus_index(BUS_NAME)
		if bus_index >= 0:
			AudioServer.remove_bus(bus_index)
		_owned_bus = false


func _exit_tree() -> void:
	shutdown()
