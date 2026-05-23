#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float iTime;
} ubuf;

float hash(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash(i),                  hash(i + vec2(1.0, 0.0)), u.x),
        mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
        u.y
    );
}

void main() {
    vec2 uv = vec2(qt_TexCoord0.x, 1.0 - qt_TexCoord0.y);
    float t = ubuf.iTime;

    vec2 fp = uv * vec2(2.0, 3.0);
    float fn = 0.0;
    fn += 0.500 * noise(fp       + vec2( t * 0.10, -t * 0.02));
    fn += 0.250 * noise(fp * 2.0 + vec2(-t * 0.14,  t * 0.03));
    fn += 0.125 * noise(fp * 4.0 + vec2( t * 0.18, -t * 0.05));
    fn /= 0.875;

    float lakeY = 0.333;
    float fog = clamp(fn - uv.y * 1.4 + 0.3, 0.0, 1.0);
    fog *= smoothstep(lakeY + 0.06, lakeY - 0.01, uv.y);
    vec3 fogCol = mix(vec3(0.50, 0.57, 0.72), vec3(0.82, 0.88, 0.95), fog);
    float alpha = smoothstep(0.02, 0.40, fog) * 0.25 * ubuf.qt_Opacity;

    fragColor = vec4(fogCol * alpha, alpha);
}
