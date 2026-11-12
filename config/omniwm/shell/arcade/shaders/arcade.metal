// Arcade bar backdrop: the pack's darkest background with a sparse starfield whose pixels twinkle slowly,
// like the attract screen of an 8-bit cabinet. values = (star amount, twinkle, -, -). fps 2.
float arcadeHash(float2 p) { return fract(sin(dot(p, float2(91.7, 271.3))) * 43758.5453); }

float4 shade(float2 uv, constant OmniShader& shader) {
    float3 background = shader.colors[omni_background].rgb * 0.6;
    float3 ink = shader.colors[omni_foreground].rgb;
    float3 accent = shader.colors[omni_accent].rgb;
    float2 cell = floor(uv * shader.size / 3.0);               // 3pt "pixels"
    float star = step(1.0 - 0.012 * clamp(shader.values.x, 0.0, 2.0), arcadeHash(cell));
    float twinkle = step(0.5, fract(arcadeHash(cell + 3.0) + shader.time * 0.25 * clamp(shader.values.y, 0.0, 2.0)));
    float3 color = mix(background, arcadeHash(cell + 9.0) < 0.2 ? accent : ink, star * mix(0.35, 0.9, twinkle));
    return float4(color, 1.0);
}
