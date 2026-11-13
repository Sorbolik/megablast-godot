shader_type canvas_item;
// An eye of the APPRENDISTA: the drawn white of the eye (its alpha is the eye's
// shape, so nothing goes out of it), the pupil drawn on it moved by look, and
// the lids: the upper one comes down, the lower one comes up a little, with the
// dark lash line on the edge. blink: 0 open, 1 closed.

uniform sampler2D pupil : filter_linear_mipmap;
uniform float blink = 0.0;
uniform vec2 look = vec2(0.0);
uniform vec4 lid_color : source_color = vec4(0.72, 0.26, 0.16, 1.0);

void fragment() {
	vec4 white = texture(TEXTURE, UV);
	vec4 p = texture(pupil, clamp(UV - look * vec2(0.16, 0.10), vec2(0.0), vec2(1.0)));
	vec3 c = mix(white.rgb, p.rgb, p.a);
	// the upper lid edge: a curve, lower in the middle; it reaches 0.8 closed
	float curve = 0.10 * (1.0 - 4.0 * (UV.x - 0.5) * (UV.x - 0.5));
	float edge = mix(-0.15, 0.80, blink) + curve * blink;
	float upper = smoothstep(edge + 0.025, edge - 0.025, UV.y);
	// the lower lid: from the bottom up to 0.8 when closed
	float low_edge = mix(1.1, 0.80, blink);
	float lower = smoothstep(low_edge - 0.025, low_edge + 0.025, UV.y);
	c = mix(c, lid_color.rgb, max(upper, lower));
	float lash = (1.0 - smoothstep(0.0, 0.07, abs(UV.y - edge))) * smoothstep(0.05, 0.25, blink);
	c = mix(c, vec3(0.0), lash * 0.95);
	COLOR = vec4(c, white.a);
}
