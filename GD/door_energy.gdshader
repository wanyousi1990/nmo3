shader_type canvas_item;
render_mode blend_mix, unshaded;

/// 門洞能量場：TEXTURE＝門洞遮罩；pattern 以菱形（奇偶列錯半格）排列。
/// pattern_density＝整面格子密度
/// motif_size＝每格內單體大小（越大越放大；可 >1 讓紋路超出單格並重疊）

uniform sampler2D pattern_tex : source_color, filter_nearest, repeat_disable;
uniform vec2 scroll_speed = vec2(-0.12, 0.12);
uniform float pattern_density : hint_range(0.5, 16.0, 0.05) = 3.0;
uniform float motif_size : hint_range(0.05, 8.0, 0.01) = 0.75;
uniform float pattern_strength : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float black_cutoff : hint_range(0.0, 1.0, 0.01) = 0.08;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	float mask_a = texture(TEXTURE, UV).a;
	if (mask_a < 0.01) {
		discard;
	}

	float density = max(pattern_density, 0.01);
	float msize = max(motif_size, 0.01);

	// 菱形排列：奇數列水平錯半格
	vec2 grid_uv = UV * density + TIME * scroll_speed;
	float row = floor(grid_uv.y);
	grid_uv.x += mod(row, 2.0) * 0.5;
	vec2 cell_uv = fract(grid_uv);

	// 在格子中把單體縮放（以格子中心為準）
	vec2 motif_uv = (cell_uv - 0.5) / msize + 0.5;
	if (motif_uv.x < 0.0 || motif_uv.x > 1.0 || motif_uv.y < 0.0 || motif_uv.y > 1.0) {
		discard;
	}

	vec4 pat = texture(pattern_tex, motif_uv);

	// 必須尊重 PNG 透明；黑底素材再用亮度門檻當備用
	float lum = max(max(pat.r, pat.g), pat.b);
	float pat_a = pat.a;
	if (lum < black_cutoff) {
		pat_a = 0.0;
	}
	if (pat_a < 0.01) {
		discard;
	}

	COLOR = vec4(pat.rgb * tint.rgb * pattern_strength, mask_a * pat_a * tint.a);
}
