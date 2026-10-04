shader_type canvas_item;
render_mode blend_mix;

// =============================================================================
// Idimya color-grade TEMPLATE (applies to all Idimya pose sprites via one shared
// material). Neutral by default: with the values below, output == source art.
// Tune the parameters on the ShaderMaterial in the Inspector.
// Alpha is always preserved exactly (no edge halos).
// =============================================================================

// Master blend. 0 = original art, 1 = full effect. Handy for A/B compare.
uniform float amount : hint_range(0.0, 1.0) = 1.0;

// Overall brightness (multiplicative). 0 = unchanged, + brighter, - darker.
// Multiplicative, so pure black stays black.
uniform float brightness : hint_range(-1.0, 1.0) = 0.0;

// Contrast around mid-gray, luminance-aware (hue/saturation preserved).
// 0 = unchanged, + = punchier (darks down / lights up), - = flatter.
uniform float contrast : hint_range(-1.0, 1.0) = 0.0;

// Saturation. 0 = unchanged, -1 = greyscale, + = more vivid.
uniform float saturation : hint_range(-1.0, 1.0) = 0.0;

// Color tint (multiplies RGB). White = unchanged. Pull toward blue for a cool
// cast, toward warm for warmth, etc.
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

const vec3 W = vec3(0.299, 0.587, 0.114); // luma weights (sRGB)

void fragment() {
	vec4 src = texture(TEXTURE, UV); // sample only -> neutral output is pixel-identical to no shader
	vec3 c = src.rgb;
	vec3 g = c;

	// Brightness (multiplicative -> black floor preserved).
	g *= (1.0 + brightness);

	// Luma-aware contrast around 0.5: pivot the luma, re-inject the delta into all
	// channels so tone changes while hue/saturation are preserved.
	float l = dot(g, W);
	float cl = (l - 0.5) * (1.0 + contrast) + 0.5;
	g += (cl - l);

	// Saturation, pivoted on the pixel's own luma.
	float l2 = dot(g, W);
	g = mix(vec3(l2), g, 1.0 + saturation);

	// Tint (color multiply).
	g *= tint.rgb;

	g = clamp(g, 0.0, 1.0);
	COLOR = vec4(mix(c, g, amount), src.a); // alpha preserved exactly
}
