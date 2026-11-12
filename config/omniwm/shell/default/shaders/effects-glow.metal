float4 shade(float2 uv, constant OmniShader& shader) {
    float2 size = max(shader.size, float2(1.0));
    float radius = clamp(shader.values.x, 0.0, min(size.x, size.y) * 0.5);
    float2 q = abs((uv - 0.5) * size) - size * 0.5 + radius;
    float distance = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
    float coverage = clamp(0.5 - distance * shader.scale, 0.0, 1.0);
    float falloff = pow(clamp(1.0 + min(distance, 0.0) / max(shader.values.y, 0.5), 0.0, 1.0),
        max(shader.values.w, 0.1));
    float4 color = shader.colors[omni_accent];
    return float4(color.rgb, color.a * coverage * falloff * clamp(shader.values.z, 0.0, 1.0));
}
