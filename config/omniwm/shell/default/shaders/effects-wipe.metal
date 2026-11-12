float4 shade(float2 uv, constant OmniShader& shader) {
    float progress = omni_progress(shader);
    if (progress <= 0.0 || progress >= 1.0) return float4(1.0, 1.0, 1.0, progress);
    float2 size = max(shader.size, float2(1.0));
    float2 direction = shader.values.xy;
    direction = length(direction) > 0.001 ? normalize(direction) : float2(1.0, 0.0);
    float span = max(dot(abs(direction), size), 1.0);
    float position = dot((uv - 0.5) * size, direction) + span * 0.5;
    float feather = max(shader.values.z, 1.0 / max(shader.scale, 1.0));
    float alpha = 1.0 - smoothstep(progress * span - feather, progress * span + feather, position);
    return float4(1.0, 1.0, 1.0, alpha);
}
