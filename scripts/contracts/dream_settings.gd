class_name DreamSettings
extends Resource

enum Locomotion { TELEPORT, CONTINUOUS }
enum Quality { LOW, DEFAULT }
@export_range(0.0, 1.0) var volume: float = 0.5
@export_range(0.0, 1.0) var visual_intensity: float = 0.5
@export var seated_mode: bool = false
@export var locomotion_mode: int = Locomotion.TELEPORT
@export var quality_tier: int = Quality.DEFAULT
