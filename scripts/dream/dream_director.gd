class_name DreamDirector
extends RefCounted

const DWELL_SECONDS: float = 90.0
const BLEND_SECONDS: float = 30.0
const MOOD_COUNT: int = 3

var _elapsed: float = 0.0

func step(delta: float, stillness: float, settings: DreamSettings) -> DreamFrame:
	if is_finite(delta) and delta > 0.0:
		_elapsed += delta
	var frame: DreamFrame = DreamFrame.new()
	frame.elapsed_seconds = _elapsed
	var phase_length: float = DWELL_SECONDS + BLEND_SECONDS
	var phase: int = int(floor(_elapsed / phase_length))
	var local_seconds: float = fmod(_elapsed, phase_length)
	frame.mood_from = phase % MOOD_COUNT
	frame.mood_to = frame.mood_from
	if local_seconds >= DWELL_SECONDS:
		frame.mood_to = (frame.mood_from + 1) % MOOD_COUNT
		frame.mood_blend = clampf((local_seconds - DWELL_SECONDS) / BLEND_SECONDS, 0.0, 1.0)
	frame.stillness = clampf(stillness, 0.0, 1.0) if is_finite(stillness) else 0.0
	frame.visual_intensity = clampf(settings.visual_intensity, 0.0, 1.0) if is_finite(settings.visual_intensity) else 0.5
	return frame

func reset_session() -> void:
	_elapsed = 0.0
