shader_type canvas_item;

uniform vec4 base_teal : source_color = vec4(0.05, 0.65, 0.6, 0.85);
uniform vec4 deep_teal : source_color = vec4(0.02, 0.35, 0.45, 0.92);
uniform vec4 soft_glow : source_color = vec4(0.45, 0.95, 0.85, 1.0);

uniform float wobble_speed : hint_range(0.5, 5.0) = 1.6;
uniform float wave_height : hint_range(0.0, 0.08) = 0.02;

void fragment() {
    vec2 uv = UV;
    
    // 1. Gentle, rounded jello wave at the top (not choppy)
    float top_wave = sin(uv.x * 5.0 + TIME * wobble_speed) * wave_height;
    top_wave += sin(uv.x * 3.0 - TIME * (wobble_speed * 0.7)) * (wave_height * 0.5);
    float surface_y = (wave_height * 2.0) + top_wave;
    
    if (uv.y < surface_y) {
        discard;
    }
    
   
    float wobble_x = sin(uv.y * 4.0 + TIME * wobble_speed) * 0.03;
    float wobble_y = cos(uv.x * 4.0 - TIME * wobble_speed) * 0.03;
    vec2 jelly_uv = uv + vec2(wobble_x, wobble_y);
    

    float blob1 = length(jelly_uv - vec2(0.35 + sin(TIME * 0.8) * 0.1, 0.45 + cos(TIME * 0.6) * 0.1));
    float blob2 = length(jelly_uv - vec2(0.7 + cos(TIME * 0.7) * 0.1, 0.6 + sin(TIME * 0.9) * 0.1));
    
   
    float glow = smoothstep(0.45, 0.05, blob1) * 0.35 + smoothstep(0.4, 0.05, blob2) * 0.25;
    
  
    float depth = clamp((uv.y - surface_y) / (1.0 - surface_y), 0.0, 1.0);
    vec4 color = mix(base_teal, deep_teal, depth);
    color.rgb = mix(color.rgb, soft_glow.rgb, glow);
    
    COLOR = color;
}