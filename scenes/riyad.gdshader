shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 lightColor : source_color = vec4(1.0, 0.95, 0.7, 1.0);
uniform float intensity : hint_range(0.0, 4.0) = 1.0;
uniform vec2 beamOrigin = vec2(0.0);
uniform float beamLength = 0.0;

uniform sampler2D shadowTex : filter_linear;
uniform vec2 beamOriginWorld = vec2(0.0);
uniform vec2 invX = vec2(1.0, 0.0);
uniform vec2 invY = vec2(0.0, 1.0);
uniform vec2 invOrigin = vec2(0.0);
uniform vec2 rectPos = vec2(0.0);
uniform vec2 rectSize = vec2(1.0);
uniform vec2 srcPos = vec2(0.0);
uniform vec2 srcSize = vec2(1.0);
uniform bool flipH = false;
uniform bool flipV = false;
uniform vec2 casterCenter = vec2(0.0);
uniform float casterRadius = 0.0;
uniform float shadowStrength : hint_range(0.0, 1.0) = 0.0;
uniform float shadowSoftness = 10.0;
uniform float shadowSpread = 0.12;

varying vec2 localPos;
varying vec2 worldPos;

void vertex() {
	localPos = VERTEX;
	worldPos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float casterAlpha(vec2 p) {
	vec2 local = vec2(dot(invX, p), dot(invY, p)) + invOrigin;
	vec2 n = (local - rectPos) / rectSize;
	if (n.x < 0.0 || n.x > 1.0 || n.y < 0.0 || n.y > 1.0) {
		return 0.0;
	}
	if (flipH) {
		n.x = 1.0 - n.x;
	}
	if (flipV) {
		n.y = 1.0 - n.y;
	}
	return textureLod(shadowTex, srcPos + n * srcSize, 0.0).a;
}

float occlusion(vec2 p) {
	if (shadowStrength <= 0.0 || casterRadius <= 0.0) {
		return 0.0;
	}
	vec2 toOrigin = beamOriginWorld - p;
	float rayLen = length(toOrigin);
	if (rayLen < 0.001) {
		return 0.0;
	}
	vec2 dir = toOrigin / rayLen;
	vec2 perp = vec2(-dir.y, dir.x);
	float tc = dot(casterCenter - p, dir);
	float blur = shadowSoftness + max(tc, 0.0) * shadowSpread;
	float reachR = casterRadius + blur;
	float miss = length(p + dir * tc - casterCenter);
	if (miss > reachR) {
		return 0.0;
	}
	float reach = sqrt(reachR * reachR - miss * miss);
	float t0 = max(tc - reach, 0.0);
	float t1 = min(tc + reach, rayLen);
	if (t1 <= t0) {
		return 0.0;
	}
	float total = 0.0;
	float weightSum = 0.0;
	for (int k = 0; k < 7; k++) {
		float f = (float(k) - 3.0) / 3.0;
		float wgt = exp(-f * f * 2.0);
		vec2 off = perp * f * blur;
		float occ = 0.0;
		for (int i = 0; i < 10; i++) {
			float t = mix(t0, t1, (float(i) + 0.5) / 10.0);
			occ = max(occ, casterAlpha(p + off + dir * t));
		}
		total += occ * wgt;
		weightSum += wgt;
	}
	return total / weightSum;
}

void fragment() {
	float fade = texture(TEXTURE, UV).r;
	float along = 1.0;
	if (beamLength > 0.0) {
		along = 1.0 - smoothstep(0.0, 1.0, length(localPos - beamOrigin) / beamLength);
	}
	float occ = occlusion(worldPos);
	occ = occ * occ * (3.0 - 2.0 * occ);
	float lit = 1.0 - occ * shadowStrength;
	COLOR = vec4(lightColor.rgb * intensity, fade * along * lightColor.a * lit);
}