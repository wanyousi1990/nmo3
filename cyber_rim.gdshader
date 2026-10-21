shader_type canvas_item;
/// 賽博輪廓：整隻合成貼圖邊緣染色。
/// 左青右紅；底圖可乘 scene_modulate／body_tint（由腳本開關）；霓虹不乘壓暗。
render_mode unshaded, blend_mix;

uniform vec4 color_left : source_color = vec4(0.15, 1.0, 1.0, 1.0);
uniform vec4 color_right : source_color = vec4(1.0, 0.2, 0.95, 1.0);
uniform float rim_px : hint_range(0.5, 12.0) = 2.5;
uniform float rim_strength : hint_range(0.0, 10.0) = 4.5;
uniform float wall_t : hint_range(0.0, 1.0) = 0.5;
uniform float wall_boost : hint_range(0.0, 5.0) = 1.5;
uniform float debug_prove_on : hint_range(0.0, 1.0) = 0.0;

uniform vec4 scene_modulate : source_color = vec4(1.0);
uniform vec4 body_tint : source_color = vec4(0.580392, 0.560784, 0.701961, 1.0);
uniform float use_scene_modulate : hint_range(0.0, 1.0) = 1.0;
uniform float use_body_tint : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec2 px = max(rim_px, 0.5) * TEXTURE_PIXEL_SIZE;

	float a = col.a;
	float a_l = texture(TEXTURE, UV + vec2(-px.x, 0.0)).a;
	float a_r = texture(TEXTURE, UV + vec2(px.x, 0.0)).a;
	float a_u = texture(TEXTURE, UV + vec2(0.0, -px.y)).a;
	float a_d = texture(TEXTURE, UV + vec2(0.0, px.y)).a;

	float sil_l = a_r * (1.0 - a) + a * max(a - a_l, 0.0);
	float sil_r = a_l * (1.0 - a) + a * max(a - a_r, 0.0);
	float sil_v = max(a_u, a_d) * (1.0 - a) + a * max(max(a - a_u, a - a_d), 0.0);

	float boost_l = 1.0 + pow(1.0 - wall_t, 1.25) * wall_boost;
	float boost_r = 1.0 + pow(wall_t, 1.25) * wall_boost;

	vec3 neon = color_left.rgb * (sil_l + sil_v * 0.35) * boost_l
		+ color_right.rgb * (sil_r + sil_v * 0.35) * boost_r;
	neon *= rim_strength;

	vec3 base_rgb = col.rgb;
	if (debug_prove_on > 0.5) {
		vec3 prove = mix(color_left.rgb, color_right.rgb, wall_t);
		base_rgb = mix(base_rgb, prove, 0.4);
	}

	vec3 tint = vec3(1.0);
	if (use_scene_modulate > 0.5) {
		tint *= scene_modulate.rgb;
	}
	if (use_body_tint > 0.5) {
		tint *= body_tint.rgb;
	}

	float rim_a = clamp(max(max(sil_l, sil_r), sil_v) * rim_strength, 0.0, 1.0);
	// 底圖乘開關色調；霓虹保持原強度
	vec3 out_rgb = base_rgb * a * tint + neon;
	float out_a = max(a, rim_a);
	COLOR = vec4(out_rgb, out_a);
}
