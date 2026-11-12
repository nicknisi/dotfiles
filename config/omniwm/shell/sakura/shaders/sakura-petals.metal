uint sakuraHash(uint value) {
    value ^= value >> 16;
    value *= 0x7feb352du;
    value ^= value >> 15;
    value *= 0x846ca68bu;
    return value ^ (value >> 16);
}

float4 shade(float2 uv, constant OmniShader& shader) {
    float strength = clamp(shader.values.x, 0.0, 1.0);
    float time = shader.time * clamp(shader.values.y, 0.0, 4.0) + shader.values.w;
    float petalSize = clamp(shader.values.z, 4.0, 24.0);
    float2 point = uv * max(shader.size, float2(1.0));
    float3 color = mix(shader.colors[omni_background].rgb, shader.colors[omni_elevatedSurface].rgb,
        0.12 + uv.x * 0.16 + uv.y * 0.06);
    uint grain = sakuraHash(uint(point.x) + uint(point.y) * 4099u);
    color += (float(grain & 255u) / 255.0 - 0.5) * 0.004;
    if (strength > 0.0) {
        for (int layer = 0; layer < 2; ++layer) {
            float depth = layer == 0 ? 0.72 : 1.0;
            float spacing = petalSize * (layer == 0 ? 9.5 : 8.0);
            float2 drift = float2(time * 6.0 + sin(time * 0.35) * 10.0, time * 14.0) * depth;
            float2 position = point - drift + float2(float(layer) * 73.0, float(layer) * 31.0);
            int2 cell = int2(floor(position / spacing));
            for (int y = -1; y <= 1; ++y) {
                for (int x = -1; x <= 1; ++x) {
                    int2 index = cell + int2(x, y);
                    uint hash = sakuraHash(uint(index.x) * 73u + uint(index.y) * 4099u + uint(layer) * 137u + 19u);
                    float seed = float(hash & 65535u) / 65535.0;
                    float other = float(hash >> 16) / 65535.0;
                    float2 center = (float2(index) + float2(seed, other) * 0.8 + 0.1) * spacing;
                    float2 local = position - center;
                    float radius = petalSize * depth * (0.72 + seed * 0.35);
                    if (dot(local, local) > radius * radius * 1.5) {
                        continue;
                    }
                    float angle = seed * 6.2831853 + time * (0.3 + other * 0.3);
                    float sine = sin(angle);
                    float cosine = cos(angle);
                    float2 petal = float2(cosine * local.x - sine * local.y,
                        sine * local.x + cosine * local.y) / radius;
                    petal.x /= 0.75 + 0.25 * cos(time * 0.7 + seed * 9.0);
                    float body = length(petal / float2(0.50 - petal.y * 0.10, 1.0)) - 1.0;
                    float notch = 0.20 - length(petal - float2(0.0, -1.04));
                    float edge = max(body, notch);
                    float aa = 1.0 / (radius * max(shader.scale, 0.5));
                    float mask = 1.0 - smoothstep(-aa, aa, edge);
                    float3 pink = mix(shader.colors[omni_pink].rgb, shader.colors[omni_accent].rgb,
                        clamp(petal.y * 0.3 + 0.35, 0.0, 1.0));
                    pink = mix(shader.colors[omni_surface].rgb, pink, 0.48 + seed * 0.22);
                    float vein = exp(-abs(petal.x) * 45.0) * smoothstep(-0.8, 0.0, petal.y)
                        * (1.0 - smoothstep(0.3, 0.9, petal.y));
                    pink = mix(pink, shader.colors[omni_accent].rgb, vein * 0.14);
                    color = mix(color, pink, mask * strength * depth);
                }
            }
        }
    }
    return float4(clamp(color, 0.0, 1.0), 1.0);
}
