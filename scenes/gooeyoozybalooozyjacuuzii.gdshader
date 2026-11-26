shader_type canvas_item;

uniform float aspect_ratio = 2.0;
uniform float rotation_speed = 0.1;
uniform vec2 scroll_direction = vec2(1.0, 0.0);
uniform float wobble_strength = 0.0;
uniform float wobble_frequency = 8.0;
uniform float wobble_speed = 1.0;
uniform bool as_shadow = false;

void fragment() {
	vec2 uv = UV;
	uv.x += sin(UV.y * wobble_frequency + TIME * wobble_speed) * wobble_strength;
	uv.y += sin(UV.x * wobble_frequency + TIME * wobble_speed * 1.3) * wobble_strength;

	vec2 flow = vec2(uv.x / aspect_ratio, uv.y) - scroll_direction * TIME * rotation_speed;
	vec2 wrapped = fract(flow);
	COLOR = textureGrad(TEXTURE, wrapped, dFdx(flow), dFdy(flow));

	if (as_shadow) {
		COLOR.rgb = vec3(0.0);
		COLOR.a *= 0.9;
	}
}
