shader_type canvas_item;
render_mode blend_mix, unshaded;

// H_FX：像素風液滴。UV 先切成格子，高光也是整格亮像素。
// Compatibility 不能寫 light()，否則整份 shader 會編譯失敗、效果全沒。
// 場景 PointLight2D 改由 OL_H_Controller 在噴出時混進粒子色。
// shape_mode 0=原本方顆粒+高光  1=像素圓（硬邊圓）

uniform int shape_mode : hint_range(0, 1) = 1;
uniform float pixel_grid : hint_range(4.0, 16.0, 1.0) = 8.0;
uniform vec2 highlight_offset = vec2(-0.28, -0.32);
uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 0.97, 1.0);
uniform float highlight_size : hint_range(0.05, 0.9) = 0.32;
uniform float highlight_strength : hint_range(0.0, 1.0) = 1.0;
uniform float volume_dark : hint_range(0.2, 1.0) = 0.72;
uniform float shade_band : hint_range(0.3, 1.0) = 0.68;

void fragment() {
	float grid = max(pixel_grid, 2.0);
	vec2 cell = floor(UV * grid);
	vec2 uv_pix = (cell + 0.5) / grid;
	vec2 p = uv_pix * 2.0 - 1.0;

	float shape_d = length(p);
	float shade_d = shape_d;
	float alpha = COLOR.a;
	if (shape_mode == 0) {
		shade_d = max(abs(p.x), abs(p.y));
	} else if (shape_d > 1.0) {
		alpha = 0.0;
	}

	vec3 body = COLOR.rgb;
	if (shade_d > shade_band) {
		body *= volume_dark;
	}

	float hd = length(p - highlight_offset);
	float inner = highlight_size * 0.5;
	if (hd < inner) {
		body = mix(body, highlight_color.rgb, highlight_strength * highlight_color.a);
	} else if (hd < highlight_size) {
		body = mix(body, highlight_color.rgb, highlight_strength * 0.4 * highlight_color.a);
	}

	COLOR = vec4(body, alpha);
}
