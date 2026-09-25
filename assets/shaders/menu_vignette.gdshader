shader_type canvas_item;

void fragment() {
	float left_panel = (1.0 - smoothstep(0.04, 0.66, UV.x)) * 0.88;
	float vignette = smoothstep(0.2, 0.95, distance(UV, vec2(0.52, 0.48)));
	float top_fade = 1.0 - smoothstep(0.0, 0.18, UV.y);
	float alpha = max(left_panel, vignette * 0.38) + top_fade * 0.18;
	COLOR = vec4(0.025, 0.035, 0.04, clamp(alpha, 0.0, 0.94));
}
