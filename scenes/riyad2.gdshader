shader_type canvas_item;

uniform vec4 darkColor : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float darkness : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	float fade = texture(TEXTURE, UV).r;
	COLOR = vec4(darkColor.rgb, darkness * fade);
}
