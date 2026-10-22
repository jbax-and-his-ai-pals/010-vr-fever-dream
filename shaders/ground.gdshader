shader_type spatial;
render_mode unshaded;

void fragment() {
	vec2 p = UV * 16.0 - vec2(8.0);
	float r = length(p);
	float rings = pow(max(0.0, cos(r * 5.8)), 50.0);
	float grid = pow(max(0.0, cos(p.x * 2.0)), 70.0) + pow(max(0.0, cos(p.y * 2.0)), 70.0);
	float fade = 1.0 - smoothstep(5.5, 8.0, r);
	ALBEDO = vec3(0.018, 0.027, 0.05) + vec3(0.025, 0.045, 0.065) * rings * fade + vec3(0.009, 0.019, 0.028) * grid * fade;
}
