shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float dream_time = 0.0;
uniform float intensity = 0.5;
uniform int mood_from = 0;
uniform int mood_to = 0;
uniform float mood_blend = 0.0;
uniform bool is_curl = false;
varying vec4 memory;

vec3 palette(int mood, float source) {
	if (mood == 1) return mix(vec3(0.8, 0.3, 0.65), vec3(1.0, 0.7, 0.32), source);
	if (mood == 2) return mix(vec3(0.24, 0.8, 0.65), vec3(1.0, 0.55, 0.72), source);
	return mix(vec3(0.2, 0.72, 0.88), vec3(0.73, 0.48, 0.96), source);
}

void vertex() {
	memory = INSTANCE_CUSTOM;
	if (memory.z < 0.5) VERTEX *= 0.0;
	if (is_curl) {
		float age = dream_time - memory.x;
		VERTEX *= smoothstep(35.0, 43.0, age);
	}
}

void fragment() {
	float age = max(0.0, dream_time - memory.x);
	float life = (1.0 - smoothstep(20.0, 90.0, age)) * memory.z;
	vec3 color = mix(palette(mood_from, memory.y), palette(mood_to, memory.y), mood_blend);
	ALBEDO = color * life * (0.3 + intensity * 0.7);
}
