shader_type canvas_item;

uniform float aspect_ratio = 2;
uniform float rotation_speed = 0.05;
uniform bool as_shadow = false;
uniform float edge_softness : hint_range(0.0, 0.5) = 0.2; // Controls how wide the edge fade/glow is

void fragment() {
	float px = 2.0 * (UV.x - 0.5);
	float py = 2.0 * (UV.y - 0.5);
	
	float dist_sq = px * px + py * py;
	
	if (dist_sq > 1.0) {
		// Outside of "sphere"
		COLOR.a = 0.0;
	} else {
		float dist = sqrt(dist_sq);
		
		// Map UVs to spherical coordinates
		float safe_denom = max(0.0001, 1.0 - py * py);
		float sphere_px = asin(px / sqrt(safe_denom)) * 2.0 / PI;
		float sphere_py = asin(py) * 2.0 / PI;
		
		COLOR = texture(TEXTURE, vec2(
			0.5 * (sphere_px + 1.0) / aspect_ratio - TIME * rotation_speed,
			0.5 * (sphere_py + 1.0)));
			
		if (as_shadow) {
			COLOR.rgb = vec3(0.0, 0.0, 0.0);
			COLOR.a *= 0.9;
		} else {
			// 1. 3D Sphere Shading (simulates a spherical surface lighting falloff)
			float sphere_z = sqrt(max(0.0, 1.0 - dist_sq));
			COLOR.rgb *= mix(0.5, 1.0, sphere_z); // Darkens the edges slightly for depth
			
			// 2. Edge Fade & Glow (smoothly fades alpha near the outer boundary)
			float edge_fade = smoothstep(1.0, 1.0 - edge_softness, dist);
			COLOR.a *= edge_fade;
			
			// 3. Rim Glow (adds a nice atmospheric highlight right along the edge)
			float rim = pow(dist, 3.0) * 0.3;
			COLOR.rgb += vec3(rim);
		}
	}
}