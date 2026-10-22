shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, skip_vertex_transform;

uniform vec4 root_color : source_color = vec4(0.075, 0.18, 0.38, 1.0);
uniform vec4 body_color : source_color = vec4(0.17, 0.8, 0.88, 1.0);
uniform vec4 tip_color : source_color = vec4(0.79, 0.64, 1.0, 1.0);
uniform float dream_time = 0.0;
uniform float shape_mood = 0.0;
uniform float intensity = 0.5;
uniform float stillness = 0.0;
uniform vec3 visitor_position = vec3(0.0, 1.65, 3.8);
uniform vec3 hand_left = vec3(0.0);
uniform vec3 hand_right = vec3(0.0);
uniform vec2 hand_strength = vec2(0.0);
uniform float influence_radius = 1.25;
uniform float bend_cap = 0.6;
uniform vec3 audio_bands = vec3(0.0);
varying vec3 cloud_coordinate;
varying float hand_glow;
varying float seed;
varying float presence;
varying float disturbance;

vec3 hand_offset(vec3 point, vec3 hand, float strength) {
	vec3 difference = hand - point;
	float distance_to_hand = length(difference);
	float weight = 1.0 - smoothstep(0.0, influence_radius, distance_to_hand);
	return difference / max(distance_to_hand, 0.01) * bend_cap * weight * strength;
}

void vertex() {
	seed = INSTANCE_CUSTOM.x;
	float phase = seed * 6.2831853;
	float time = dream_time * 0.10;
	disturbance = INSTANCE_CUSTOM.w;
	cloud_coordinate = VERTEX;
	vec3 p = VERTEX;
	// Broad folds avoid detailed surfaces and keep the shape ambiguous.
	float lobes = sin(p.x * 2.8 + phase + time) * sin(p.y * 2.3 - time * 0.7);
	lobes += cos(p.z * 3.1 + p.y * 1.7 + phase - time) * 0.55;
	p *= 1.0 + lobes * (0.18 + intensity * 0.08 + disturbance * 0.09);
	p += disturbance * 0.16 * sin(p.yzx * 2.1 + phase + time * 1.4);
	p.x += sin(p.y * 2.6 + phase + time) * 0.20;
	p.z += sin(p.x * 2.2 - p.y * 1.6 + time * 0.6 + phase) * 0.19;
	vec3 world = (MODEL_MATRIX * vec4(p, 1.0)).xyz;
	world += vec3(sin(time * 0.5 + phase), cos(time * 0.4 + phase), sin(time * 0.37 - phase)) * 0.22;
	vec3 bend = hand_offset(world, hand_left, hand_strength.x) + hand_offset(world, hand_right, hand_strength.y);
	float total_bend = length(bend);
	bend *= min(1.0, bend_cap / max(total_bend, 0.001));
	hand_glow = min(1.0, total_bend / max(bend_cap, 0.001));
	world += bend * (0.3 + 0.7 * intensity);
	// Dissolve near the visitor rather than forcing them through a hard shell.
	float range = distance(MODEL_MATRIX[3].xyz, visitor_position);
	float proximity = smoothstep(0.55, 2.2, range) * (1.0 - smoothstep(8.0, 11.5, range));
	presence = proximity * (0.58 + 0.42 * sin(time * 0.37 + phase) * sin(time * 0.37 + phase));
	NORMAL = normalize((VIEW_MATRIX * vec4(MODEL_NORMAL_MATRIX * NORMAL, 0.0)).xyz);
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
}

void fragment() {
	vec3 p = cloud_coordinate;
	float phase = seed * 6.2831853;
	float time = dream_time * 0.07;
	p += disturbance * 0.55 * sin(p.zxy * 1.7 + phase + time);
	vec3 warped = p + vec3(sin(p.y * 2.2 + time + phase), cos(p.z * 2.1 - time), sin(p.x * 2.5 + time * 0.6)) * 0.35;
	float mixing = 0.5 + 0.5 * sin(warped.x * 2.0 + warped.y * 2.2 - warped.z * 1.7 + phase + time);
	float veil = 0.5 + 0.5 * cos(warped.z * 3.0 + warped.y * 2.0 - time + phase);
	vec3 color = mix(root_color.rgb, body_color.rgb, mixing);
	color = mix(color, tip_color.rgb, veil * 0.28 + 0.07 * sin(time + phase));
	color = mix(color, vec3(0.68, 0.85, 0.91), hand_glow * 0.28);
	color = mix(color, mix(vec3(0.53, 0.16, 0.42), vec3(0.24, 0.61, 0.51), veil), disturbance * 0.48);
	// Feather the silhouette; there is no lighting or hard rim highlight.
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float feather = smoothstep(0.05, 0.66, facing);
	float density = mix(0.12, 0.48, smoothstep(0.05, 0.95, mixing * veil));
	ALBEDO = color * (0.64 + intensity * 0.20 + audio_bands.y * 0.04);
	ALPHA = feather * density * presence * (0.82 + 0.12 * stillness + disturbance * 0.28);
}
