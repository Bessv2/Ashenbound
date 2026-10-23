shader_type spatial;
// Look B ("grim world"): the model's palette texture made heavy and worn.
// Colours are muted and darkened; a baked noise texture adds pitted relief,
// grime in the hollows and varying roughness, so stone, iron and bone read
// as real materials under the torches. Bright, grey texels (steel) turn
// metallic. With `cutout` on, it also opens the see-through hole around the
// hero, like occluder_cutout.gdshader. With `use_detail` on (the world), real
// photographed stone (Poly Haven, CC0) is laid over it by world position:
// flagstones on upward faces, rock blocks on the sides, with their relief and
// roughness, keeping the palette's colour. Visual only.
//
// Built for phones: everything is projected along the one world axis the
// surface faces most (no triplanar blend), and the noise is a texture
// (tools/art/make_grime_noise.py), so a pixel costs four to five texture
// reads and no procedural noise.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float desaturate = 0.45;
uniform float darken = 0.72;
uniform float relief = 1.0;
uniform float noise_scale = 2.2;
uniform float metal_bias = 1.0;
uniform float grime_amount = 1.0;
uniform bool cutout = false;
uniform float cutout_radius = 2.2;
// RG: fine relief normal; B: fine noise; A: coarse noise (where grime gathers).
uniform sampler2D grime_noise : filter_linear_mipmap, repeat_enable;
uniform bool use_detail = false;
uniform sampler2D detail_top_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_top_normal : filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_top_roughness : filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_side_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_side_normal : filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_side_roughness : filter_linear_mipmap, repeat_enable;
// Repeats per metre: one over the photographed surface's real size.
uniform float detail_top_scale = 0.5;
uniform float detail_side_scale = 0.55;
uniform float detail_strength = 0.85;
// The photographs' average brightness (linear), so they shade the palette
// colour instead of replacing it.
uniform float detail_top_mean = 0.195;
uniform float detail_side_mean = 0.075;

global uniform vec3 occlusion_focus;

varying vec3 world_pos;
varying vec3 world_normal;

float bayer4(vec2 frag) {
	ivec2 p = ivec2(mod(frag, 4.0));
	int index = p.x + p.y * 4;
	const float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
			3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[index] / 16.0;
}

// A tangent-space normal `t` (z out of the surface) turned into world space
// on the plane facing `axis` (0 x, 1 y, 2 z), around the surface normal `wn`.
vec3 axis_normal(vec3 t, vec3 wn, int axis) {
	if (axis == 0) {
		return normalize(vec3(abs(t.z) * wn.x, t.y + wn.y, t.x + wn.z));
	} else if (axis == 1) {
		return normalize(vec3(t.x + wn.x, abs(t.z) * wn.y, t.y + wn.z));
	}
	return normalize(vec3(t.x + wn.x, t.y + wn.y, abs(t.z) * wn.z));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = texture(albedo_texture, UV).rgb * tint.rgb;
	float grey = dot(base, vec3(0.299, 0.587, 0.114));
	float saturation = length(base - vec3(grey));
	vec3 wn = normalize(world_normal);
	vec3 facing = abs(wn);
	int axis = facing.y >= facing.x && facing.y >= facing.z ? 1 : (facing.x >= facing.z ? 0 : 2);
	vec2 plane = axis == 1 ? world_pos.xz : (axis == 0 ? world_pos.zy : world_pos.xy);
	// Fine noise and its relief, then coarse noise for the grime: two reads.
	vec4 fine = texture(grime_noise, plane * noise_scale * 0.12);
	float coarse = texture(grime_noise, plane * noise_scale * 0.045 + vec2(0.37, 0.61)).a;
	float n = fine.b;
	float grime = smoothstep(0.35, 0.75, coarse) * grime_amount;
	vec3 muted = mix(base, vec3(grey), desaturate) * darken;
	vec3 albedo = muted * mix(0.78, 1.08, n) * mix(1.0, 0.62, grime);
	vec3 bump = vec3((fine.rg * 2.0 - 1.0) * 0.6 * relief, 1.0);
	vec3 bent = axis_normal(bump, wn, axis);
	float metal = smoothstep(0.55, 0.8, grey) * (1.0 - smoothstep(0.05, 0.18, saturation)) * metal_bias;
	// Damp hollows: grime is wet and catches the torchlight.
	float wet = smoothstep(0.55, 0.85, grime);
	float roughness = clamp(mix(0.78, 0.3, max(metal, wet)) + (n - 0.5) * 0.3, 0.08, 1.0);
	if (use_detail) {
		// The photograph for this face: flagstones on top, rock on the sides.
		bool top = axis == 1;
		vec2 uv = plane * (top ? detail_top_scale : detail_side_scale);
		vec3 photo = (top ? texture(detail_top_albedo, uv).rgb : texture(detail_side_albedo, uv).rgb)
				/ (top ? detail_top_mean : detail_side_mean);
		float photo_rough = top ? texture(detail_top_roughness, uv).r : texture(detail_side_roughness, uv).r;
		vec3 t = (top ? texture(detail_top_normal, uv).rgb : texture(detail_side_normal, uv).rgb) * 2.0 - 1.0;
		vec3 photo_normal = axis_normal(t, wn, axis);
		float photo_grey = dot(photo, vec3(0.299, 0.587, 0.114));
		vec3 shaded = muted * mix(vec3(photo_grey), photo, 0.35) * mix(1.0, 0.75, grime);
		albedo = mix(albedo, shaded, detail_strength);
		bent = normalize(mix(bent, photo_normal, detail_strength));
		roughness = mix(roughness, mix(photo_rough, 0.3, wet), detail_strength);
	}
	ALBEDO = albedo;
	NORMAL = normalize((VIEW_MATRIX * vec4(bent, 0.0)).xyz);
	METALLIC = metal * 0.45;
	ROUGHNESS = roughness;
	SPECULAR = mix(0.5, 0.9, wet);
	EMISSION = emission_color.rgb * emission_energy;
	if (cutout && !IN_SHADOW_PASS) {
		vec3 focus = (VIEW_MATRIX * vec4(occlusion_focus, 1.0)).xyz;
		if (VERTEX.z > focus.z + 0.5) {
			float across = length(VERTEX.xy - focus.xy);
			float keep = smoothstep(cutout_radius * 0.7, cutout_radius, across);
			if (keep < bayer4(FRAGCOORD.xy)) {
				discard;
			}
		}
	}
}
