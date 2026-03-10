shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

uniform float u_time = 0.0;
uniform vec2 mesh_origin = vec2(0.0);
uniform float patch_inner_radius = 0.0;
uniform float patch_outer_radius = 5000.0;
uniform vec4 shallow_color : source_color = vec4(0.05, 0.42, 0.52, 1.0);
uniform vec4 deep_color : source_color = vec4(0.02, 0.10, 0.22, 1.0);
uniform vec4 crest_color : source_color = vec4(0.10, 0.56, 0.94, 1.0);
uniform vec4 foam_color : source_color = vec4(0.90, 0.97, 1.0, 1.0);
uniform float wave_amplitude = 1.0;
uniform float wave_frequency = 1.0;
uniform float wave_speed = 1.0;
uniform float metallic_level = 0.06;
uniform float roughness_level = 0.10;
uniform vec4 wake_points[16];

varying float v_crest;
varying float v_height;
varying float v_patch_dist;
varying vec2 v_world_xz;
varying float v_view_depth;

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

void wake_state(vec2 p, out float wake_height, out float wake_foam) {
	wake_height = 0.0;
	wake_foam = 0.0;

	for (int i = 0; i < 16; i++) {
		vec4 wake_point = wake_points[i];
		float strength = wake_point.w;
		if (strength <= 0.001) {
			continue;
		}

		vec2 rel = p - wake_point.xy;
		float dist = length(rel);
		float age = wake_point.z;
		float age_ratio = clamp(age / 1.6, 0.0, 1.0);
		float radius = 0.35 + age * 4.8;
		float width = mix(0.16, 0.42, age_ratio);
		float ring = exp(-pow((dist - radius) / max(width, 0.001), 2.0));
		float inner_ring = exp(-pow((dist - radius * 0.55) / max(width * 0.8, 0.001), 2.0));
		float ripple = sin((dist - radius) * 16.0 - age * 7.5);
		float decay = (1.0 - age_ratio);
		float core = exp(-dist * 2.8) * exp(-age * 3.2);

		wake_height += ring * ripple * 0.055 * strength * decay;
		wake_height += inner_ring * 0.016 * strength * decay;

		float foam_ring = ring * (0.65 + 0.35 * sin(dist * 24.0 - age * 10.0));
		float foam_speckle = 0.5 + 0.5 * sin(rel.x * 18.0 + rel.y * 22.0 - age * 12.0);
		wake_foam += foam_ring * foam_speckle * 0.75 * strength * decay;
		wake_foam += core * 0.28 * strength;
	}

	wake_foam = clamp(wake_foam, 0.0, 1.0);
}

float water_detail(vec2 p, out vec2 grad) {
	float phase_a = dot(p, vec2(1.18, -0.74)) * 0.42 + u_time * 2.6;
	float phase_b = dot(p, vec2(-0.82, -1.27)) * 0.68 - u_time * 3.3;
	float phase_c = dot(p, vec2(1.91, 0.56)) * 1.24 + u_time * 4.4;

	float a = sin(phase_a);
	float b = sin(phase_b);
	float c = sin(phase_c);
	float blend = a * 0.50 + b * 0.32 + c * 0.18;

	grad =
		vec2(1.18, -0.74) * cos(phase_a) * 0.42 * 0.50 +
		vec2(-0.82, -1.27) * cos(phase_b) * 0.68 * 0.32 +
		vec2(1.91, 0.56) * cos(phase_c) * 1.24 * 0.18;
	return blend;
}

void vertex() {
	vec2 world_p = VERTEX.xz + mesh_origin;
	float height = 0.0;
	vec3 normal = wave_state(world_p, height);
	float wake_height = 0.0;
	float wake_foam = 0.0;
	wake_state(world_p, wake_height, wake_foam);
	float total_height = height + wake_height;
	VERTEX.y += total_height;
	NORMAL = normal;
	v_crest = clamp(1.0 - normal.y, 0.0, 1.0);
	v_height = total_height;
	v_patch_dist = length(VERTEX.xz);
	vec4 world_vertex = MODEL_MATRIX * vec4(VERTEX, 1.0);
	v_world_xz = world_vertex.xz;
	v_view_depth = max(-(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z, 0.0);
}

void fragment() {
	if (v_patch_dist < patch_inner_radius || v_patch_dist > patch_outer_radius) {
		discard;
	}

	float wake_height = 0.0;
	float wake_foam_mask = 0.0;
	wake_state(v_world_xz, wake_height, wake_foam_mask);
	vec2 detail_grad = vec2(0.0);
	float detail = water_detail(v_world_xz, detail_grad);
	float scene_depth_sample = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_depth_sample, 1.0);
	vec3 scene_view_pos = view.xyz / view.w;
	float scene_depth = max(-scene_view_pos.z, 0.0);
	float water_depth = v_view_depth;
	float thickness = max(scene_depth - water_depth, 0.0);
	vec3 detail_normal = normalize(vec3(-detail_grad.x * 0.18, 1.0, -detail_grad.y * 0.18));
	vec3 blended_normal = normalize(NORMAL + detail_normal * 0.35);
	float fresnel = pow(1.0 - max(dot(normalize(blended_normal), normalize(VIEW)), 0.0), 3.6);
	float depth_mix = clamp(1.0 - exp(-thickness * 0.18), 0.0, 1.0);
	float intersection_foam = (1.0 - smoothstep(0.0, 1.15, thickness)) * step(0.01, thickness);
	intersection_foam *= 0.55 + 0.45 * smoothstep(-0.75, 0.75, detail);
	float wake_foam = clamp(wake_foam_mask * (0.7 + 0.3 * smoothstep(-0.65, 0.9, detail)), 0.0, 1.0);
	float crest = clamp(v_crest * 2.3 + smoothstep(0.55, 1.8, abs(v_height)) * 0.28 + smoothstep(0.30, 0.95, detail) * 0.10, 0.0, 1.0);
	float foam = clamp(intersection_foam * 1.05 + wake_foam * 0.95 + crest * 0.14, 0.0, 1.0);
	vec3 water_tint = mix(shallow_color.rgb, deep_color.rgb, clamp(depth_mix + abs(v_height) * 0.07, 0.0, 1.0));
	vec2 refract_offset = blended_normal.xz * (0.010 + depth_mix * 0.016 + wake_foam * 0.010);
	vec3 scene_color = textureLod(screen_texture, SCREEN_UV + refract_offset, 0.0).rgb;
	vec3 tint_mix = mix(water_tint, crest_color.rgb, clamp(crest * 0.55 + fresnel * 0.30, 0.0, 1.0));
	vec3 base = mix(scene_color, tint_mix, 0.28 + depth_mix * 0.34 + fresnel * 0.22);
	ALBEDO = mix(base, foam_color.rgb, foam * 0.88);
	EMISSION = foam_color.rgb * foam * (0.08 + wake_foam * 0.10);
	METALLIC = metallic_level;
	ROUGHNESS = clamp(roughness_level + depth_mix * 0.10 - crest * 0.08 - detail * 0.04 + foam * 0.14, 0.03, 0.28);
	SPECULAR = 0.92;
	ALPHA = clamp(0.12 + depth_mix * 0.18 + fresnel * 0.14 + foam * 0.10, 0.10, 0.46);
}
