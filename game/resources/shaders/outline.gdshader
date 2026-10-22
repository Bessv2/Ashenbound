shader_type spatial;
// Inverted-hull outline: the back faces, pushed out along the normals and
// drawn in one dark colour, so the hero's silhouette reads against a dark
// floor. Used as a next pass on the hero's material. Visual only.
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

uniform vec4 outline_color : source_color = vec4(0.02, 0.01, 0.02, 1.0);
uniform float width = 0.012;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
