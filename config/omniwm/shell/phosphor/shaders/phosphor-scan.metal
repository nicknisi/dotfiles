// Phosphor bar backdrop: the pack's background with a faint accent tint, CRT scanlines, a glowing bottom
// edge and soft vignetted ends. Static (fps 0). values = (scanline darkness, accent tint, edge glow, -).
float4 shade(float2 uv, constant OmniShader& shader) {
    float4 background = shader.colors[omni_background];
    float4 accent = shader.colors[omni_accent];
    float y = uv.y * shader.size.y;
    float scan = step(2.0, fmod(y, 3.0)) * clamp(shader.values.x, 0.0, 1.0);
    float3 color = mix(background.rgb, accent.rgb, clamp(shader.values.y, 0.0, 1.0)) * (1.0 - scan);
    float fromBottom = (1.0 - uv.y) * shader.size.y;
    float edge = exp(-fromBottom / 1.6) * clamp(shader.values.z, 0.0, 1.0);
    color = mix(color, accent.rgb, clamp(edge, 0.0, 1.0));
    float ends = smoothstep(0.0, 0.06, uv.x) * smoothstep(0.0, 0.06, 1.0 - uv.x);
    color *= mix(0.82, 1.0, ends);
    return float4(color, 1.0);
}
