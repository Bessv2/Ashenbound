// Procedural flagstone floor. Tiles are laid out in world space, so the floor
// gives a stable visual reference for movement without any texture assets.
shader_type spatial;

uniform vec3 stone_color : source_color = vec3(0.17, 0.16, 0.18);
uniform vec3 grout_color : source_color = vec3(0.06, 0.05, 0.07);
uniform float tile_size = 2.0;
uniform float grout_width = 0.05;
uniform float tile_variation : hint_range(0.0, 0.5) = 0.18;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 cell = world_position.xz / tile_size;
	vec2 in_cell = fract(cell);
	// Distance to the nearest tile edge, in meters.
	float edge = min(min(in_cell.x, 1.0 - in_cell.x), min(in_cell.y, 1.0 - in_cell.y)) * tile_size;
	float aa = fwidth(edge);
	float grout = 1.0 - smoothstep(grout_width - aa, grout_width + aa, edge);
	// Per-tile brightness jitter so the floor does not read as a flat grid.
	float noise = fract(sin(dot(floor(cell), vec2(12.9898, 78.233))) * 43758.5453);
	vec3 stone = stone_color * (1.0 - tile_variation + 2.0 * tile_variation * noise);
	ALBEDO = mix(stone, grout_color, grout);
	ROUGHNESS = 0.95;
}
