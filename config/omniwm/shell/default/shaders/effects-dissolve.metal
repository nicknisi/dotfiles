float4 shade(float2 uv, constant OmniShader& shader) {
    float progress = omni_progress(shader);
    if (progress <= 0.0 || progress >= 1.0) return float4(1.0, 1.0, 1.0, progress);
    float2 cell = floor(uv * shader.size / max(shader.values.x, 1.0));
    uint seed = as_type<uint>(shader.values.z);
    uint hash = uint(cell.x) * 1664525u + uint(cell.y) * 1013904223u + seed;
    hash ^= hash >> 16;
    hash *= 2246822519u;
    hash ^= hash >> 13;
    float threshold = float(hash & 65535u) / 65535.0;
    float softness = clamp(shader.values.y, 0.001, 1.0) * 0.08;
    float alpha = smoothstep(threshold - softness, threshold + softness, progress);
    return float4(1.0, 1.0, 1.0, alpha);
}
