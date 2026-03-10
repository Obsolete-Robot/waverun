shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform float u_time = 0.0;
uniform vec2 mesh_origin = vec2(0.0);
uniform float patch_inner_radius = 0.0;
uniform float patch_outer_radius = 5000.0;
uniform vec4 deep_color : source_color = vec4(0.02, 0.10, 0.22, 1.0);
uniform vec4 crest_color : source_color = vec4(0.10, 0.56, 0.94, 1.0);
uniform float wave_amplitude = 1.0;
uniform float wave_frequency = 1.0;
uniform float wave_speed = 1.0;
uniform float metallic_level = 0.06;
uniform float roughness_level = 0.10;

varying float v_crest;
varying float v_height;
varying float v_patch_dist;

void accumulate_wave(
	vec2 p,
	vec2 dir,
	float amp,
	float freq,
	float speed,
	float phase_offset,
	inout float height,
	inout float grad_x,
	inout float grad_y
) {
	float scaled_freq = freq * wave_frequency;
	float scaled_speed = speed * sqrt(max(wave_frequency, 0.001));
	float phase = dot(p, dir) * scaled_freq + u_time * scaled_speed * wave_speed + phase_offset;
	float s = sin(phase);
	float c = cos(phase);

	height += s * amp * wave_amplitude;
	grad_x += c * amp * wave_amplitude * scaled_freq * dir.x;
	grad_y += c * amp * wave_amplitude * scaled_freq * dir.y;
}

vec3 wave_state(vec2 p, out float height) {
	float grad_x = 0.0;
	float grad_y = 0.0;
	height = 0.0;

	accumulate_wave(p, vec2(0.978, 0.210), 0.72, 0.008, 0.40, 0.0, height, grad_x, grad_y);
	accumulate_wave(p, vec2(-0.612, 0.791), 0.36, 0.014, 0.62, 1.1, height, grad_x, grad_y);
	accumulate_wave(p, vec2(0.334, 0.943), 0.22, 0.024, 0.88, 2.4, height, grad_x, grad_y);
	accumulate_wave(p, vec2(-0.935, 0.355), 0.16, 0.038, 1.18, 0.65, height, grad_x, grad_y);
	accumulate_wave(p, vec2(0.822, -0.569), 0.11, 0.061, 1.58, 1.9, height, grad_x, grad_y);
	accumulate_wave(p, vec2(-0.179, -0.984), 0.08, 0.092, 2.05, 2.8, height, grad_x, grad_y);
	accumulate_wave(p, vec2(0.608, 0.794), 0.06, 0.138, 2.75, 0.45, height, grad_x, grad_y);
	accumulate_wave(p, vec2(-0.768, -0.640), 0.04, 0.205, 3.45, 1.55, height, grad_x, grad_y);

	return normalize(vec3(-grad_x, 1.0, -grad_y));
}

void vertex() {
	vec2 world_p = VERTEX.xz + mesh_origin;
	float height = 0.0;
	vec3 normal = wave_state(world_p, height);
	VERTEX.y += height;
	NORMAL = normal;
	v_crest = clamp(1.0 - normal.y, 0.0, 1.0);
	v_height = height;
	v_patch_dist = length(VERTEX.xz);
}

void fragment() {
	if (v_patch_dist < patch_inner_radius || v_patch_dist > patch_outer_radius) {
		discard;
	}

	float fresnel = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 3.1);
	float crest = clamp(v_crest * 2.6 + smoothstep(0.55, 1.8, abs(v_height)) * 0.26, 0.0, 1.0);
	vec3 base = mix(deep_color.rgb, crest_color.rgb, clamp(crest * 1.7, 0.0, 1.0));
	ALBEDO = mix(base, vec3(0.90, 0.96, 1.0), crest * 0.20 + fresnel * 0.35);
	METALLIC = metallic_level;
	ROUGHNESS = max(0.05, roughness_level - crest * 0.03) + fresnel * 0.16;
	SPECULAR = 0.95;
}
