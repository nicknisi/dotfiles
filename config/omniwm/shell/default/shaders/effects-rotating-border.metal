float4 shade(float2 uv, constant OmniShader& shader) {
    float2 size = max(shader.size, float2(1.0));
    float radius = clamp(shader.values.x, 0.0, min(size.x, size.y) * 0.5);
    float2 q = abs((uv - 0.5) * size) - size * 0.5 + radius;
    float distance = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
    float stroke = clamp(shader.values.y, 0.0, min(size.x, size.y) * 0.5);
    float outside = clamp(0.5 - distance * shader.scale, 0.0, 1.0);
    float inside = clamp(0.5 + (distance + stroke) * shader.scale, 0.0, 1.0);
    float angle = shader.time * shader.values.z * M_PI_F / 180.0;
    float2 direction = float2(cos(angle), sin(angle));
    float span = max(dot(abs(direction), size), 1.0);
    float blend = clamp(0.5 + dot((uv - 0.5) * size, direction) / span, 0.0, 1.0);
    float4 color = mix(shader.colors[omni_accent], shader.colors[omni_purple], blend);
    return float4(color.rgb, color.a * outside * inside * clamp(shader.values.w, 0.0, 1.0)
        * (stroke > 0.0 ? 1.0 : 0.0));
}
