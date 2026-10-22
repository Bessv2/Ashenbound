shader_type spatial;
// A flickering flame on a camera-facing quad: a teardrop of light whose
// edges lick upward with time. Additive and unshaded, so it glows through the
// environment's bloom. Visual only.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 core_color : source_color = vec4(1.0, 0.85, 0.45, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.35, 0.08, 1.0);
uniform float intensity = 2.2;
uniform float speed = 1.0;
uniform float seed = 0.0;

void vertex() {
	// Billboard around the vertical axis only, so the flame stays upright.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], MODEL_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

float wave(float x, float t) {
	return sin(x * 9.0 + t * 7.3) * 0.5 + sin(x * 5.0 - t * 11.1) * 0.35 + sin(t * 3.7 + x * 2.0) * 0.15;
}

void fragment() {
	float t = TIME * speed + seed * 13.7;
	vec2 uv = UV;
	float h = 1.0 - uv.y;                       // 0 at the base, 1 at the tip
	float sway = wave(h, t) * 0.07 * h;
	float x = (uv.x - 0.5 - sway) * 2.0;
	// Teardrop: wide near the base, a point at the tip, round at the bottom.
	float width = mix(0.95, 0.04, pow(h, 0.85)) * smoothstep(0.0, 0.18, h + 0.05);
	float body = 1.0 - smoothstep(width * 0.55, width, abs(x));
	float flicker = 0.82 + 0.18 * sin(t * 17.0 + seed * 4.0) * sin(t * 6.1);
	float tip_fade = 1.0 - smoothstep(0.65, 1.0, h + wave(uv.x, t * 1.3) * 0.05);
	float alpha = body * tip_fade * flicker;
	float core = 1.0 - smoothstep(0.0, width * 0.5, abs(x));
	vec3 color = mix(edge_color.rgb, core_color.rgb, core * (1.0 - h * 0.7));
	ALBEDO = color * alpha * intensity;
	ALPHA = alpha;
}
