shader_type spatial;
// The KayKit dungeon material, plus a see-through hole wherever this surface
// stands between the camera and the hero, so walls and pillars never hide
// the player. The hole follows the global `occlusion_focus` (set every frame
// by OcclusionFocus) and has a dithered edge. Shadows are unaffected.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform float roughness = 0.45;
// Radius of the hole, in metres across the screen (the camera is orthographic).
uniform float cutout_radius = 2.2;

global uniform vec3 occlusion_focus;

// 4x4 ordered dither threshold in [0, 1).
float bayer4(vec2 frag) {
	ivec2 p = ivec2(mod(frag, 4.0));
	int index = p.x + p.y * 4;
	const float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
			3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[index] / 16.0;
}

void fragment() {
	ALBEDO = texture(albedo_texture, UV).rgb;
	ROUGHNESS = roughness;
	METALLIC = 0.0;
	if (!IN_SHADOW_PASS) {
		vec3 focus = (VIEW_MATRIX * vec4(occlusion_focus, 1.0)).xyz;
		// In view space the camera looks down -Z: a larger z is nearer to it.
		if (VERTEX.z > focus.z + 0.5) {
			float across = length(VERTEX.xy - focus.xy);
			float keep = smoothstep(cutout_radius * 0.7, cutout_radius, across);
			if (keep < bayer4(FRAGCOORD.xy)) {
				discard;
			}
		}
	}
}
