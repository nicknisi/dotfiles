float4 shade(float2 uv, constant OmniShader& shader) {
    float p = omni_progress(shader);
    bool haze = shader.values.z > 0.5;
    if (p <= 0.0 || p >= 1.0) return haze ? float4(0) : float4(1, 1, 1, p);
    float2 point = uv * shader.size / max(shader.values.x, 1.0);
    float cloud = omni_noise(point) * 0.55 + omni_noise(point * 2.03 + 11.0) * 0.3
        + omni_noise(point * 4.07 + 19.0) * 0.15;
    float field = (1.0 - uv.y) * 0.45 + cloud * 0.55;
    float softness = max(shader.values.y, 0.001);
    float alpha = smoothstep(field - softness, field + softness, p);
    if (!haze) return float4(1, 1, 1, alpha);
    float envelope = smoothstep(0.0, 0.15, p) * (1.0 - smoothstep(0.85, 1.0, p));
    float plume = (1.0 - smoothstep(0.0, softness * 2.0, abs(p - field))) * alpha;
    return float4(mix(float3(0.25, 0.3, 0.4), float3(0.85, 0.9, 1.0), cloud), plume * 0.7 * envelope);
}
