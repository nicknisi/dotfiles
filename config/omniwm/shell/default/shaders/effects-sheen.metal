float4 shade(float2 uv, constant OmniShader& shader) {
    float strength = clamp(shader.values.x, 0.0, 1.0);
    float frequency = max(shader.values.y, 0.1);
    float phase = (uv.x * 0.7 + uv.y * 0.4) * frequency * 2.0 * M_PI_F;
    float3 pearl = 0.65 + 0.35 * cos(phase + float3(0.0, 2.1, 4.2));
    float band = pow(0.5 + 0.5 * cos(phase), 6.0);
    float4 accent = shader.colors[omni_accent];
    return float4(mix(accent.rgb, pearl, 0.7), strength * (0.12 + 0.5 * band) * accent.a);
}
