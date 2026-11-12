float4 shade(float2 uv, constant OmniShader& shader) {
    float p = omni_progress(shader);
    bool edge = shader.values.z > 0.5;
    if (p <= 0.0 || p >= 1.0) return edge ? float4(0) : float4(1, 1, 1, p);
    float2 point = uv * shader.size / max(shader.values.x, 1.0);
    float noise = 0.65 * omni_noise(point) + 0.35 * omni_noise(point * 2.1 + 7.0);
    float field = (1.0 - uv.y) * 0.76 + noise * 0.24;
    float feather = max(shader.values.y, 0.001);
    float alpha = smoothstep(field - feather, field + feather, p);
    if (!edge) return float4(1, 1, 1, alpha);
    float envelope = smoothstep(0.0, 0.15, p) * (1.0 - smoothstep(0.85, 1.0, p));
    float ember = 1.0 - smoothstep(feather, feather * 4.0, abs(p - field));
    float3 color = mix(float3(1.0, 0.12, 0.01), float3(1.0, 0.85, 0.25), ember);
    return float4(color, ember * alpha * envelope);
}
