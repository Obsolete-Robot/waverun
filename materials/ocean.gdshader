shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform float u_time = 0.0;
uniform vec4 deep_color : source_color = vec4(0.02, 0.10, 0.22, 1.0);
uniform vec4 crest_color : source_color = vec4(0.08, 0.48, 0.86, 1.0);
uniform float wave_scale = 1.0;
uniform float metallic_level = 0.06;
uniform float roughness_level = 0.10;

float wave_h(vec2 p) {
	float h = 0.0;
	h += sin(dot(p, normalize(vec2(1.0, 0.25))) * 0.050 + u_time * 1.80) * 2.40;
	h += sin(dot(p, normalize(vec2(-0.70, 1.0))) * 0.092 + u_time * 2.45 + 1.4) * 1.30;
	h += sin(dot(p, normalize(vec2(0.30, 1.0))) * 0.165 + u_time * 3.15 + 2.1) * 0.55;
	return h * wave_scale;
}

void vertex() {
	float h = wave_h(VERTEX.xz);
	VERTEX.y += h;

	vec2 e = vec2(0.75, 0.0);
	float hx = wave_h(VERTEX.xz + e.xy) - wave_h(VERTEX.xz - e.xy);
	float hz = wave_h(VERTEX.xz + e.yx) - wave_h(VERTEX.xz - e.yx);
	NORMAL = normalize(vec3(-hx, 2.0, -hz));
}

void fragment() {
	float fresnel = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 3.1);
	float crest = clamp(1.0 - NORMAL.y, 0.0, 1.0);
	vec3 base = mix(deep_color.rgb, crest_color.rgb, clamp(crest * 2.0, 0.0, 1.0));
	ALBEDO = mix(base, vec3(0.78, 0.90, 1.0), fresnel * 0.35);
	METALLIC = metallic_level;
	ROUGHNESS = roughness_level + fresnel * 0.16;
	SPECULAR = 0.95;
}
