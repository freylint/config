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
    // uv: (0,0) = bottom-left, (1,1) = top-right
    vec2 uv = vec2(qt_TexCoord0.x, 1.0 - qt_TexCoord0.y);
    float t = ubuf.iTime;

    // ── Scene ───────────────────────────────────────────────────

    // Sky: deep violet at zenith, dark teal-blue at horizon
    vec3 scene = mix(
        vec3(0.02, 0.06, 0.14),
        vec3(0.06, 0.01, 0.18),
        pow(uv.y, 0.7)
    );

    // Aurora: two animated sine ribbons blended with slow noise
    float a1 = sin(uv.x * 6.0 + t * 0.25) * 0.5 + 0.5;
    float a2 = sin(uv.x * 2.5 - t * 0.13 + 1.5) * 0.5 + 0.5;
    float aurora = a1 * a2 * smoothstep(0.45, 0.75, uv.y);
    aurora = aurora * 0.6 + noise(vec2(uv.x * 4.0, t * 0.1))
             * exp(-abs(uv.y - 0.65) * 8.0) * 0.4;
    scene += vec3(0.0, 0.5, 0.3) * aurora * 0.35;
    scene += vec3(0.3, 0.0, 0.5) * aurora * 0.15;

    // Stars: sparse 4-pointed diffraction spikes
    vec2 sGrid = vec2(50.0, 35.0);
    vec2 sCell = floor(uv * sGrid);
    vec2 sFrac = fract(uv * sGrid) - 0.5;   // centred in cell
    float sSeed = hash(sCell);
    float hasStar = step(0.85, sSeed);       // ~15 % of cells get a star
    float mag = pow((sSeed - 0.85) / 0.15, 0.5) * 2.5;
    float sr = length(sFrac);
    float hSpike = exp(-abs(sFrac.x) * 18.0) * exp(-sFrac.y * sFrac.y * 160.0);
    float vSpike = exp(-abs(sFrac.y) * 18.0) * exp(-sFrac.x * sFrac.x * 160.0);
    float disc   = exp(-sr * 55.0);
    float shape  = max(disc, (hSpike + vSpike) * 0.45);
    float twinkle = 0.65 + 0.35 * sin(t * 2.2 + hash(sCell + 17.3) * 43.7);
    float fadePhase = hash(sCell + 53.1) * 6.2832;
    float fadeSpeed = 0.18 + hash(sCell + 71.9) * 0.12;
    float fade = smoothstep(-0.3, 0.3, sin(t * fadeSpeed + fadePhase));
    float star = hasStar * mag * shape * twinkle * fade * smoothstep(0.25, 0.55, uv.y);
    scene += vec3(0.88, 0.93, 1.0) * star;

    float lakeY = 0.333;

    // ── Lake ────────────────────────────────────────────────────

    float inLake = smoothstep(lakeY + 0.004, lakeY - 0.004, uv.y);

    // Wave surface normals: layered sine waves at different angles/speeds
    float wx = uv.x;
    float wave1 = sin(wx * 18.0 + t * 1.8) * 0.012
                + sin(wx * 11.0 - t * 1.1) * 0.008;
    float wave2 = sin(wx * 27.0 + t * 2.5 + 1.3) * 0.005
                + sin(wx *  7.0 - t * 0.7 + 2.1) * 0.010;
    float waveY = (lakeY - uv.y) / lakeY;   // 0 at surface, 1 at bottom
    float waveAtten = exp(-waveY * 6.0);     // waves weaken away from surface
    float distortX = (wave1 + wave2) * waveAtten;

    // Ripple distortion (fine chop on top of waves)
    vec2 rp = vec2(uv.x * 5.0, uv.y * 30.0);
    float distortNoise = noise(rp       + vec2( t * 0.35,  t * 0.60)) * 0.010
                       + noise(rp * 2.1 + vec2(-t * 0.25,  t * 0.45)) * 0.004;
    float distort = distortX + distortNoise;

    // Mirror UV around lake surface
    vec2 refUV = vec2(uv.x + distort, 2.0 * lakeY - uv.y);

    // Sky colour at reflected UV
    vec3 refSky = mix(vec3(0.02, 0.06, 0.14), vec3(0.06, 0.01, 0.18),
                      pow(clamp(refUV.y, 0.0, 1.0), 0.7));
    float ra1 = sin(refUV.x * 6.0 + t * 0.25) * 0.5 + 0.5;
    float ra2 = sin(refUV.x * 2.5 - t * 0.13 + 1.5) * 0.5 + 0.5;
    float rAurora = ra1 * ra2 * smoothstep(0.45, 0.75, refUV.y);
    rAurora = rAurora * 0.6 + noise(vec2(refUV.x * 4.0, t * 0.1))
              * exp(-abs(refUV.y - 0.65) * 8.0) * 0.4;
    refSky += vec3(0.0, 0.5, 0.3) * rAurora * 0.35
            + vec3(0.3, 0.0, 0.5) * rAurora * 0.15;

    // Specular highlights on wave crests
    float spec = pow(max(0.0, sin(wx * 18.0 + t * 1.8) * 0.5 + 0.5), 8.0) * waveAtten * 0.18
               + pow(max(0.0, sin(wx * 27.0 + t * 2.5 + 1.3) * 0.5 + 0.5), 6.0) * waveAtten * 0.10;

    // Deeper water is darker and less reflective
    float wDepth = 1.0 - clamp(uv.y / lakeY, 0.0, 1.0);
    vec3 lakeCol = mix(refSky * 0.72, vec3(0.02, 0.04, 0.10), wDepth * 0.35);
    lakeCol += vec3(0.70, 0.80, 0.95) * spec;

    scene = mix(scene, lakeCol, inLake);

    // ── Fog ─────────────────────────────────────────────────────

    // Slow horizontal drift with gentle curl — no upward rush
    vec2 fp = uv * vec2(2.0, 3.0);
    float fn = 0.0;
    fn += 0.500 * noise(fp       + vec2( t * 0.10, -t * 0.02));
    fn += 0.250 * noise(fp * 2.0 + vec2(-t * 0.14,  t * 0.03));
    fn += 0.125 * noise(fp * 4.0 + vec2( t * 0.18, -t * 0.05));
    fn /= 0.875;

    // Dense at water surface, cut off sharply ~6% above it
    float fog = clamp(fn - uv.y * 1.4 + 0.3, 0.0, 1.0);
    fog *= smoothstep(lakeY + 0.06, lakeY - 0.01, uv.y);

    // Cool moonlit mist: dark blue-grey → pale silver-white
    vec3 fogCol = mix(vec3(0.50, 0.57, 0.72), vec3(0.82, 0.88, 0.95), fog);

    // ── Composite ───────────────────────────────────────────────

    // Faint cold luminance pooling at the ground
    scene += vec3(0.18, 0.22, 0.32) * smoothstep(0.35, 0.0, uv.y) * fn * 0.35;

    // Fog is semi-transparent — scene shows through
    vec3 col = mix(scene, fogCol, smoothstep(0.02, 0.40, fog) * 0.25);

    fragColor = vec4(col * ubuf.qt_Opacity, ubuf.qt_Opacity);
}
