shader_type canvas_item;
render_mode blend_mix;

// Full-screen gaussian-ish blur that reads the framebuffer (needs a BackBufferCopy
// before it). `amount` = blur radius in pixels; 0 = clean passthrough. Used for
// the "glasses removed" moment — a strong pass on the stage, a subtle pass on the
// front (text), each faded in over ~0.5s.

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float amount = 0.0;

void fragment() {
	if (amount <= 0.001) {
		COLOR = texture(screen, SCREEN_UV);
	} else {
		vec2 ps = SCREEN_PIXEL_SIZE * amount;
		vec4 c = texture(screen, SCREEN_UV) * 0.30;
		float wsum = 0.30;
		for (int r = 1; r <= 3; r++) {
			float w = 0.7 / float(r * 3);
			vec2 o = ps * float(r);
			c += texture(screen, SCREEN_UV + vec2(o.x, 0.0)) * w; wsum += w;
			c += texture(screen, SCREEN_UV - vec2(o.x, 0.0)) * w; wsum += w;
			c += texture(screen, SCREEN_UV + vec2(0.0, o.y)) * w; wsum += w;
			c += texture(screen, SCREEN_UV - vec2(0.0, o.y)) * w; wsum += w;
			float wd = w * 0.7;
			c += texture(screen, SCREEN_UV + vec2(o.x, o.y)) * wd; wsum += wd;
			c += texture(screen, SCREEN_UV + vec2(-o.x, o.y)) * wd; wsum += wd;
			c += texture(screen, SCREEN_UV + vec2(o.x, -o.y)) * wd; wsum += wd;
			c += texture(screen, SCREEN_UV + vec2(-o.x, -o.y)) * wd; wsum += wd;
		}
		COLOR = c / wsum;
	}
}
