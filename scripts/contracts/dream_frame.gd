class_name DreamFrame
extends RefCounted

enum Mood { SILK, CORAL, AURORA }
var elapsed_seconds: float = 0.0
var mood_from: int = Mood.SILK
var mood_to: int = Mood.SILK
var mood_blend: float = 0.0
var stillness: float = 0.0
var visual_intensity: float = 0.5
