shader_type canvas_item;
// The screen's frame: a soft vignette, a faint grain, and a red pulse at the
// edges when the hero is badly hurt. Drawn over the world as a translucent
// overlay (no screen read), so it costs one cheap full-screen pass.

uniform float vignette = 0.85;
uniform float grain = 0.035;
// 0 = healthy, 1 = at death's door.
uniform float danger = 0.0;
uniform vec4 danger_color : source_color = vec4(0.55, 0.0, 0.02, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 centered = UV - 0.5;
	centered.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float edge = smoothstep(0.18, 0.78, length(centered) * 1.1);
	float pulse = danger * (0.55 + 0.45 * sin(TIME * (3.0 + danger * 3.0)));
	float noise = (hash(UV * 731.0 + fract(TIME * 13.0)) - 0.5) * grain;
	vec3 color = mix(vec3(0.0), danger_color.rgb, clamp(pulse * 1.2, 0.0, 1.0));
	float alpha = clamp(edge * vignette + edge * pulse * 0.6, 0.0, 0.95);
	COLOR = vec4(color + noise, alpha + abs(noise));
}
