shader_type spatial;
// Look B ("grim world"): the model's palette texture made heavy and worn.
// Colours are muted and darkened, and a world-space noise adds pitted, uneven
// relief, grime in the hollows and varying roughness, so stone, iron and bone
// read as real materials under the torches. Bright, grey texels (steel) turn
// metallic. With `cutout` on, it also opens the see-through hole around the
// hero, like occluder_cutout.gdshader. With `use_detail` on (the world), real
// photographed stone (Poly Haven, CC0) is laid over it by world position:
// flagstones on upward faces, rock blocks on the sides, with their relief and
// roughness, keeping the palette's colour. Visual only.

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
uniform bool use_detail = false;
uniform sampler2D detail_top_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_top_normal : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_top_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_side_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_side_normal : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_side_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
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

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	return noise(p) * 0.55 + noise(p * 2.13) * 0.28 + noise(p * 4.71) * 0.17;
}

float bayer4(vec2 frag) {
	ivec2 p = ivec2(mod(frag, 4.0));
	int index = p.x + p.y * 4;
	const float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
			3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[index] / 16.0;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = texture(albedo_texture, UV).rgb * tint.rgb;
	float grey = dot(base, vec3(0.299, 0.587, 0.114));
	float saturation = length(base - vec3(grey));
	vec3 p = world_pos * noise_scale;
	float n = fbm(p);
	float grime = smoothstep(0.35, 0.75, fbm(p * 0.37 + 11.0)) * grime_amount;
	vec3 muted = mix(base, vec3(grey), desaturate) * darken;
	vec3 albedo = muted * mix(0.78, 1.08, n) * mix(1.0, 0.62, grime);
	// Relief: bend the normal along the noise's slope.
	float e = 0.05;
	vec3 grad = vec3(fbm(p + vec3(e, 0, 0)) - n, fbm(p + vec3(0, e, 0)) - n, fbm(p + vec3(0, 0, e)) - n) / e;
	vec3 bent = normalize(world_normal - grad * 0.06 * relief);
	float metal = smoothstep(0.55, 0.8, grey) * (1.0 - smoothstep(0.05, 0.18, saturation)) * metal_bias;
	// Damp hollows: grime is wet and catches the torchlight.
	float wet = smoothstep(0.55, 0.85, grime);
	float roughness = clamp(mix(0.78, 0.3, max(metal, wet)) + (n - 0.5) * 0.3, 0.08, 1.0);
	if (use_detail) {
		// Triplanar: each axis projects its own photograph, blended by how
		// much the surface faces that axis.
		vec3 wn = normalize(world_normal);
		vec3 blend = pow(abs(wn), vec3(4.0));
		blend /= dot(blend, vec3(1.0));
		vec2 uv_x = world_pos.zy * detail_side_scale;
		vec2 uv_y = world_pos.xz * detail_top_scale;
		vec2 uv_z = world_pos.xy * detail_side_scale;
		// Each photograph relative to its own average: 1 is an average texel.
		vec3 photo = texture(detail_side_albedo, uv_x).rgb / detail_side_mean * blend.x
				+ texture(detail_top_albedo, uv_y).rgb / detail_top_mean * blend.y
				+ texture(detail_side_albedo, uv_z).rgb / detail_side_mean * blend.z;
		float photo_rough = texture(detail_side_roughness, uv_x).r * blend.x
				+ texture(detail_top_roughness, uv_y).r * blend.y
				+ texture(detail_side_roughness, uv_z).r * blend.z;
		// Whiteout blend of the three tangent-space normals into world space.
		vec3 tx = texture(detail_side_normal, uv_x).rgb * 2.0 - 1.0;
		vec3 ty = texture(detail_top_normal, uv_y).rgb * 2.0 - 1.0;
		vec3 tz = texture(detail_side_normal, uv_z).rgb * 2.0 - 1.0;
		tx = vec3(tx.xy + wn.zy, abs(tx.z) * wn.x);
		ty = vec3(ty.xy + wn.xz, abs(ty.z) * wn.y);
		tz = vec3(tz.xy + wn.xy, abs(tz.z) * wn.z);
		vec3 photo_normal = normalize(tx.zyx * blend.x + ty.xzy * blend.y + tz.xyz * blend.z);
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
