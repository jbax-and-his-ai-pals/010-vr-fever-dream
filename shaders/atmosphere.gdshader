shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

uniform float flow_time = 0.0;
uniform float intensity : hint_range(0.0, 1.0) = 0.5;
uniform vec3 visitor_position = vec3(0.0, 3.0, 0.0);
uniform vec3 travel_phase = vec3(0.0);
varying vec3 shell_direction;
varying float pressure;

mat2 turn(float angle) {
	float s = sin(angle);
	float c = cos(angle);
	return mat2(vec2(c, s), vec2(-s, c));
}

void vertex() {
	// Object-space direction keeps the pattern continuous across UV seams/poles
	// and fixed to the sphere when the visitor turns or walks.
	shell_direction = normalize(VERTEX);
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 away = world - visitor_position;
	pressure = 0.5 + 0.5 * sin(dot(shell_direction, vec3(1.7, 2.3, 1.1)) + dot(sin(travel_phase), vec3(0.7, 1.1, 0.9)));
	// The nearby skin bows away; keep the enclosing sphere's centre stationary.
	VERTEX += normalize(VERTEX) * pressure * 1.8;
}

void fragment() {
	vec3 direction = normalize(shell_direction);
	vec3 p = direction * 3.8;
	float t = flow_time * 0.012;
	p += pressure * 0.45 * sin(direction.yzx * 4.0 + travel_phase + vec3(t, -t, t * 0.6));
	// Nested vortices shear the previous layer into coloured fluid filaments.
	// Analytic waves avoid textures, screen feedback, and expensive noise stacks.
	for (int layer = 0; layer < 3; layer++) {
		float k = float(layer);
		p.xy = turn(1.7 * sin(length(p.xy) * 1.35 - t * (0.7 + k * 0.13) + p.z * 0.55)) * p.xy;
		p.yz = turn(1.2 * sin(length(p.yz) * 1.6 + t * 0.6 + p.x * 0.45)) * p.yz;
		p += 0.32 * sin(p.zxy * 2.1 + vec3(t, -t * 0.8, t * 0.6) + k * 1.9);
	}
	float field = p.x * 2.3 + p.y * 1.1 + sin(p.z * 2.8 - t);
	float footprint = fwidth(field);
	float pools = 0.5 + 0.5 * sin(field + t * 0.22) * (1.0 - smoothstep(0.6, 2.0, footprint));
	float dye = 0.5 + 0.5 * sin(p.y * 1.7 - p.z + t * 0.31);
	vec3 ink = vec3(0.025, 0.014, 0.07);
	vec3 petrol = vec3(0.025, 0.31, 0.36);
	vec3 bruised = vec3(0.42, 0.055, 0.28);
	vec3 acid = vec3(0.64, 0.34, 0.065);
	vec3 fluid = mix(petrol, bruised, dye);
	fluid = mix(fluid, acid, smoothstep(0.7, 0.98, pools) * 0.65);
	float folds = 0.5 + 0.5 * sin(field * 3.7 + sin(p.z * 4.0)) * (1.0 - smoothstep(0.15, 0.7, footprint));
	// Fade filaments finer than a pixel so moving eyes don't see aliased speckles.
	float veins = pow(0.5 + 0.5 * sin(field * 8.0), 12.0) * (1.0 - smoothstep(0.04, 0.18, footprint));
	vec3 color = mix(ink, fluid, 0.25 + 0.65 * pools);
	color *= 0.65 + 0.35 * folds;
	color += vec3(0.18, 0.29, 0.26) * veins * (0.12 + intensity * 0.18);
	// Slow dye drift; no global rotation or flashing of the surrounding world.
	color *= 0.9 + 0.1 * sin(vec3(0.0, 2.1, 4.2) + t * 0.2);
	color = mix(color, color.brg * vec3(1.2, 0.9, 1.1), pressure * 0.45);
	ALBEDO = color * mix(0.65, 1.2, intensity);
}
