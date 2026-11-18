// 描边（反向外扩壳），挂在 toon_unit 的 next_pass 上
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

uniform float width = 0.018;
uniform vec3 outline_color : source_color = vec3(0.05, 0.055, 0.10);

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = outline_color;
}
