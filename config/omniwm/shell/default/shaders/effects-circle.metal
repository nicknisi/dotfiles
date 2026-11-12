float4 shade(float2 uv, constant OmniShader& shader) {
    float progress = omni_progress(shader);
    if (progress <= 0.0 || progress >= 1.0) return float4(1.0, 1.0, 1.0, progress);
    float2 size = max(shader.size, float2(1.0));
    float2 origin = clamp(shader.values.xy, 0.0, 1.0);
    float reach = length(max(origin, 1.0 - origin) * size);
    float distance = length((uv - origin) * size);
    float feather = max(shader.values.z, 1.0 / max(shader.scale, 1.0));
    float alpha = 1.0 - smoothstep(progress * reach - feather, progress * reach + feather, distance);
    return float4(1.0, 1.0, 1.0, alpha);
}
