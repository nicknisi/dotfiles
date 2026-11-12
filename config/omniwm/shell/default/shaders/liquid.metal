// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

float liquidBox(float2 p, float2 center, float2 extent, float radius) {
    float2 q = abs(p - center) - extent + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

float liquidUnion(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float4 shade(float2 uv, constant OmniShader& shader) {
    float2 p = uv * shader.size;
    float t = smoothstep(0.0, 1.0, shader.progress);
    float2 extent = mix(float2(4.0), shader.content.zw * 0.5, t);
    float2 center = mix(shader.anchor, shader.content.xy + shader.content.zw * 0.5, t);
    float box = liquidBox(p, center, extent, mix(4.0, 14.0, t));
    float drop = length(p - shader.anchor) - mix(6.0, 3.0, t);
    float shape = liquidUnion(box, drop, 16.0 * t + 1.0);
    float alpha = clamp(0.5 - shape, 0.0, 1.0) * shader.colors[omni_elevatedSurface].a;
    return float4(shader.colors[omni_elevatedSurface].rgb, alpha);
}
