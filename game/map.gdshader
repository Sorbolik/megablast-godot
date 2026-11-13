shader_type canvas_item;
// The painted terrain cut by the collision mask (as battle/terrain.fp in
// MegaBlast): where the cells are empty (craters) it is transparent. The mask
// is 760 x 360 cells with linear filtering, so the edges come out soft.

uniform sampler2D mask : filter_linear;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float m = texture(mask, UV).r;
	COLOR = vec4(c.rgb, c.a * smoothstep(0.3, 0.7, m));
}
