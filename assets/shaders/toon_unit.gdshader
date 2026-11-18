// 卡通单位着色器（玩具沙盘风格 + 程序化表面细节）
// 伪太阳光：不依赖场景灯光，保证所有单位明暗一致
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform vec3 sun_dir = vec3(0.42, 0.72, -0.42);
uniform vec3 shadow_tint : source_color = vec3(0.58, 0.63, 0.86);
uniform vec3 lit_tint : source_color = vec3(1.06, 1.01, 0.94);
uniform float band_lo = 0.24;
uniform float band_hi = 0.66;
uniform vec3 rim_color : source_color = vec3(0.55, 0.85, 1.0);
uniform float rim_strength = 0.30;
uniform float rim_power = 2.6;
uniform float spec_strength = 0.16;
uniform float spec_power = 18.0;
uniform float grain_amount = 0.02;    // 程序化颗粒（三平面，无 UV）
uniform float grain_scale = 7.0;
uniform float metal_spec = 0.55;      // 金属额外高光强度

// 每个实例单独控制（状态效果）
instance uniform float u_flash = 0.0;
instance uniform float u_freeze = 0.0;
instance uniform float u_poison = 0.0;
instance uniform float u_dark = 0.0;
instance uniform float u_curse = 0.0;
instance uniform float u_rage = 0.0;
instance uniform float u_slow = 0.0;
uniform float vertex_srgb = 1.0;
uniform float emissive_boost = 1.0;

float hash31(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash31(i);
	float n100 = hash31(i + vec3(1, 0, 0));
	float n010 = hash31(i + vec3(0, 1, 0));
	float n110 = hash31(i + vec3(1, 1, 0));
	float n001 = hash31(i + vec3(0, 0, 1));
	float n101 = hash31(i + vec3(1, 0, 1));
	float n011 = hash31(i + vec3(0, 1, 1));
	float n111 = hash31(i + vec3(1, 1, 1));
	float nx00 = mix(n000, n100, f.x);
	float nx10 = mix(n010, n110, f.x);
	float nx01 = mix(n001, n101, f.x);
	float nx11 = mix(n011, n111, f.x);
	return mix(mix(nx00, nx10, f.y), mix(nx01, nx11, f.y), f.z);
}

void fragment() {
	vec3 base = COLOR.rgb;
	if (vertex_srgb > 0.5) {
		base = pow(base, vec3(2.2));
	}

	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 sun = normalize(sun_dir);
	vec3 wpos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 vdir = normalize(CAMERA_POSITION_WORLD - wpos);

	// 三平面程序化颗粒：两层噪声，打散塑料感
	float g1 = vnoise(wpos * grain_scale);
	float g2 = vnoise(wpos * grain_scale * 3.1 + vec3(11.0, 5.0, 7.0));
	float grain = clamp(g1 * 0.65 + g2 * 0.35, 0.0, 1.0);

	float ndl = clamp(dot(wn, sun), 0.0, 1.0);
	float s1 = smoothstep(band_lo, band_lo + 0.02, ndl);
	float s2 = smoothstep(band_hi, band_hi + 0.04, ndl);
	float shade = mix(0.74, 0.92, s1);
	shade = mix(shade, 1.02, s2);
	// 颗粒参与明暗，凹凸感
	shade *= 1.0 + (grain - 0.5) * grain_amount;

	vec3 col = base;
	col *= mix(shadow_tint, vec3(1.0), s1);
	col *= mix(vec3(1.0), lit_tint, s2);
	col *= shade;

	// 金属度近似：亮且低饱和的部件（钢/金/石）给更强高光与粉尘差异
	float mx = max(base.r, max(base.g, base.b));
	float mn = min(base.r, min(base.g, base.b));
	float sat = (mx - mn) / max(mx, 1e-4);
	float metal = smoothstep(0.50, 0.85, mx) * (1.0 - smoothstep(0.14, 0.42, sat));

	vec3 hv = normalize(sun + vdir);
	float sp = pow(clamp(dot(wn, hv), 0.0, 1.0), spec_power) * spec_strength * s2;
	float sp_metal = pow(clamp(dot(wn, hv), 0.0, 1.0), spec_power * 2.2) * metal_spec * metal * s2;
	col += vec3(sp + sp_metal) * (0.85 + 0.30 * grain);

	// 边缘光
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	col += rim_color * fres * rim_strength * (0.25 + 0.75 * s1);

	// 颗粒暗部（缝隙/灰尘）
	col *= 1.0 - (1.0 - grain) * 0.05;

	col = mix(col, vec3(0.42, 0.72, 0.95) * (0.45 + 0.55 * shade), u_freeze * 0.60);
	col = mix(col, vec3(0.30, 0.68, 0.22) * (0.50 + 0.55 * shade), u_poison * 0.40);
	col = mix(col, vec3(1.0), clamp(u_flash, 0.0, 1.0) * 0.80);
	col = mix(col, col * 0.28, clamp(u_dark, 0.0, 1.0));

	float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
	col = mix(vec3(lum), col, 1.14);
	col = clamp(col, vec3(0.0), vec3(1.4));
	ALBEDO = col * emissive_boost;
}
