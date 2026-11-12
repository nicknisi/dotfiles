// Blueprint bar backdrop: drafting paper tinted with the pack's blue, a fine 8pt grid with a heavier
// line every 40pt, and a ruler of ticks along the bottom edge. Static (fps 0).
// values = (blue tint, minor line strength, major line strength, -).
float4 shade(float2 uv, constant OmniShader& shader) {
    float3 background = shader.colors[omni_background].rgb;
    float3 blue = shader.colors[omni_blue].rgb;
    float3 ink = shader.colors[omni_foreground].rgb;
    float3 paper = mix(background, blue, clamp(shader.values.x, 0.0, 1.0));
    float2 point = uv * shader.size;
    float2 minor = abs(fract(point / 8.0 - 0.5) - 0.5) * 8.0;
    float2 major = abs(fract(point / 40.0 - 0.5) - 0.5) * 40.0;
    float minorLine = 1.0 - smoothstep(0.0, 0.6, min(minor.x, minor.y));
    float majorLine = 1.0 - smoothstep(0.0, 0.8, min(major.x, major.y));
    float fromBottom = (1.0 - uv.y) * shader.size.y;
    float tick = step(fmod(point.x, 8.0), 0.8) * step(fromBottom, fmod(point.x, 40.0) < 1.0 ? 6.0 : 3.0);
    float3 color = mix(paper, ink, minorLine * shader.values.y + majorLine * shader.values.z);
    color = mix(color, ink, tick * 0.5);
    return float4(color, 1.0);
}
