shader_type canvas_item;

uniform vec4 base_teal : source_color = vec4(0.05, 0.65, 0.6, 0.85);
uniform vec4 deep_teal : source_color = vec4(0.02, 0.35, 0.45, 0.92);
uniform vec4 soft_glow : source_color = vec4(0.45, 0.95, 0.85, 1.0);

uniform float wobble_speed : hint_range(0.5, 5.0) = 1.6;
uniform float wave_height : hint_range(0.0, 30.0) = 6.0;
uniform float wave_length : hint_range(20.0, 600.0) = 120.0;
uniform float depth_range : hint_range(50.0, 3000.0) = 600.0;
uniform float glow_size : hint_range(100.0, 1500.0) = 400.0;

uniform sampler2D cell_data : filter_nearest;
uniform vec2 grid_origin = vec2(0.0);
uniform vec2 cell_size = vec2(100.0);
uniform ivec2 grid_size = ivec2(0);

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

vec2 cell_info(ivec2 c) {
	if (c.x < 0 || c.y < 0 || c.x >= grid_size.x || c.y >= grid_size.y) {
		return vec2(0.0);
	}
	return texelFetch(cell_data, c, 0).rg;
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 grid = (world_pos - grid_origin) / cell_size;
	ivec2 cell = ivec2(floor(grid));
	vec2 f = fract(grid);

	float cells_above = floor(cell_info(cell).r * 255.0 + 0.5);
	bool is_surface = cell_info(cell + ivec2(0, -1)).g < 0.5;
	float px_in_cell = f.y * cell_size.y;

	float top_wave = sin(world_pos.x / wave_length + TIME * wobble_speed) * wave_height;
	top_wave += sin(world_pos.x / (wave_length * 1.7) - TIME * (wobble_speed * 0.7)) * (wave_height * 0.5);
	float surface_cut = wave_height * 2.0 + top_wave;

	if (is_surface && px_in_cell < surface_cut) {
		discard;
	}

	float depth_px = max(cells_above * cell_size.y + px_in_cell - surface_cut, 0.0);
	float depth = clamp(depth_px / depth_range, 0.0, 1.0);

	vec2 p = world_pos / glow_size;
	p += vec2(sin(p.y * 4.0 + TIME * wobble_speed), cos(p.x * 4.0 - TIME * wobble_speed)) * 0.03;

	vec2 id = floor(p);
	vec2 q = fract(p);
	float glow = 0.0;
	for (int oy = -1; oy <= 1; oy++) {
		for (int ox = -1; ox <= 1; ox++) {
			vec2 o = vec2(float(ox), float(oy));
			vec2 cid = id + o;
			float h1 = hash21(cid) * 6.2831;
			float h2 = hash21(cid + 17.0) * 6.2831;
			vec2 c1 = o + vec2(0.35 + sin(TIME * 0.8 + h1) * 0.1, 0.45 + cos(TIME * 0.6 + h1) * 0.1);
			vec2 c2 = o + vec2(0.7 + cos(TIME * 0.7 + h2) * 0.1, 0.6 + sin(TIME * 0.9 + h2) * 0.1);
			glow += smoothstep(0.45, 0.05, length(q - c1)) * 0.35;
			glow += smoothstep(0.4, 0.05, length(q - c2)) * 0.25;
		}
	}
	glow = min(glow, 1.0);

	vec4 color = mix(base_teal, deep_teal, depth);
	color.rgb = mix(color.rgb, soft_glow.rgb, glow);

	COLOR = color;
}
