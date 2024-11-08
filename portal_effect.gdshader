shader_type spatial;
render_mode blend_add, unshaded, depth_draw_always;  // Changed depth_prepass to depth_draw_always

uniform vec4 portal_color : source_color = vec4(0.0, 0.5, 1.0, 1.0);
uniform float effect_intensity : hint_range(0.0, 5.0) = 2.0;
uniform float hover_intensity : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	VERTEX.y += 0.02;  // Ensure it renders above base mesh
}

void fragment() {
	// Create circular UV coordinates
	vec2 uv = UV * 2.0 - 1.0;
	float radius = length(uv);
	float angle = atan(uv.y, uv.x);

	// Hard cutoff for anything beyond radius of 1
	if (radius > 1.0) {
		discard;
	}

	// Time-based animation
	float time = TIME * effect_intensity;

	// Create multiple swirl layers with more pronounced effect
	float swirl1 = sin(angle * 3.0 + radius * 5.0 - time) * 1.2;
	float swirl2 = cos(angle * 2.0 - radius * 4.0 + time * 0.8) * 1.2;

	// Combine swirls
	float swirl = (swirl1 + swirl2) * 0.5;

	// Create soft circular mask with smoother falloff
	float edge_mask = smoothstep(1.0, 0.2, radius);

	// Add some noise to the edge
	float noise = fract(sin(dot(uv, vec2(12.9898, 78.233)) * 43758.5453) * time);
	edge_mask *= 1.0 + noise * 0.2;

	// Pulsing effect
	float pulse = sin(time) * 0.2 + 0.8;

	// Combine effects with stronger values
	vec4 final_color = portal_color;
	final_color.a = edge_mask * pulse * (0.9 + swirl * 0.3);
	final_color.rgb *= (1.0 + swirl * 0.4) * 2.0;

	// Add center glow
	float center_glow = (1.0 - radius * 0.7) * pulse * 1.5;
	final_color.rgb += portal_color.rgb * center_glow;

	ALBEDO = final_color.rgb;
	ALPHA = clamp(final_color.a * 1.5, 0.0, 1.0);
	EMISSION = final_color.rgb * effect_intensity * (1.0 + center_glow) * 2.0;
}