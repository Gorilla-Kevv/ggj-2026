shader_type canvas_item;

// 小地图后处理：把精细瓦片压成平色大色块，只保留整体结构。
// 用法：放在小地图 SubViewport 内的全屏 ColorRect 上
//       (ColorRect 需放在 CanvasLayer layer>=1 下，以无视 canvas_transform)。
// 参数：
//   block_uv - 色块粒度 (SCREEN_UV 单位，越小色块越多；0.02 ≈ 每行 50 块)
//   levels   - 每通道色阶数，越小越"平"，调低可压掉瓦片纹理噪点

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float block_uv : hint_range(0.002, 0.2, 0.001) = 0.02;
uniform int levels : hint_range(2, 16, 1) = 5;

void fragment() {
	vec2 uv = SCREEN_UV;
	// 像素化：采样点对齐到粗网格中心，一个色块一个采样点
	vec2 snapped = (floor(uv / block_uv) + 0.5) * block_uv;
	vec3 col = texture(screen_texture, snapped).rgb;
	// 色阶压缩：渐变变成平色块
	col = floor(col * float(levels)) / float(levels);
	COLOR = vec4(col, 1.0);
}