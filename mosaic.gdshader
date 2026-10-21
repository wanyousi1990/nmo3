shader_type canvas_item;
// 螢幕取樣已含 CanvasModulate／燈光結果；不可再吃 2D 燈光，否則馬賽克會二次壓暗
render_mode unshaded;

// 抓取螢幕畫面
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// 現在變數變得直覺了：數值越大，馬賽克格子越大（單位：像素）
uniform float pixel_size : hint_range(1.0, 100.0) = 16.0;
uniform bool enabled = true;

void fragment() {
	if (enabled) {
		// 1. 獲取螢幕的實際像素尺寸 (例如 1920x1080)
		vec2 screen_size = vec2(textureSize(SCREEN_TEXTURE, 0));

		// 2. 將 UV 座標轉換為實際像素座標
		vec2 pixel_pos = SCREEN_UV * screen_size;

		// 3. 進行對齊計算：將座標縮減到指定大小的網格中心
		// 這樣無論螢幕比例如何，馬賽克永遠會維持正方形
		vec2 m_pos = floor(pixel_pos / pixel_size) * pixel_size + (pixel_size * 0.5);

		// 4. 將像素座標轉回 UV 座標進行取樣
		vec4 color = texture(SCREEN_TEXTURE, m_pos / screen_size);
		COLOR = color;
	} else {
		COLOR = texture(SCREEN_TEXTURE, SCREEN_UV);
	}
}
