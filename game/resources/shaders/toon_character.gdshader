shader_type spatial;
// Look A ("bold heroes"): cel-shaded characters. The model's own palette
// texture, lit in a few hard bands with a bright rim, so heroes and enemies
// read as deliberate, graphic cartoon figures. Visual only.
render_mode diffuse_toon, specular_toon;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float saturation = 1.45;
uniform float rim_strength = 1.2;
uniform vec4 rim_color : source_color = vec4(1.0, 0.92, 0.8, 1.0);

void fragment() {
	vec3 base = texture(albedo_texture, UV).rgb * tint.rgb;
	float grey = dot(base, vec3(0.299, 0.587, 0.114));
	ALBEDO = clamp(mix(vec3(grey), base, saturation), 0.0, 1.0);
	ROUGHNESS = 0.85;
	SPECULAR = 0.3;
	EMISSION = emission_color.rgb * emission_energy;
	// A hard rim on the silhouette, brightest where it faces away from the camera.
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	EMISSION += rim_color.rgb * step(0.62, rim) * rim_strength * 0.35;
}

void light() {
	// Three hard bands instead of a smooth falloff.
	float n = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float band = n > 0.5 ? 1.15 : (n > 0.15 ? 0.6 : 0.18);
	DIFFUSE_LIGHT += band * LIGHT_COLOR / PI;
}
