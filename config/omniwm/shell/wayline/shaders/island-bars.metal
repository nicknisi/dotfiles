// Live music bars for the notch island: shader.audio holds 60 spectrum bands (0..1, 50 Hz to 10 kHz),
// updated 30x a second without re-rendering Luau. values.x = bar count, values.y = gap fraction.
float4 shade(float2 uv, constant OmniShader& shader) {
    float bars = max(shader.values.x, 1.0);
    float gap = clamp(shader.values.y, 0.0, 0.9);
    float index = floor(uv.x * bars);
    float local = fract(uv.x * bars);
    // Each bar takes the loudest band in its slice of the lower 48 bands (the top ones are mostly air).
    int lo = int(index / bars * 48.0);
    int hi = max(int((index + 1.0) / bars * 48.0), lo + 1);
    float level = 0.0;
    for (int band = lo; band < hi; band++) level = max(level, shader.audio[band]);
    level = clamp(pow(level, 0.75) * 1.25, 0.12, 1.0);
    // Bars grow from the middle, with softly rounded ends.
    float half_width = (1.0 - gap) * 0.5;
    float dx = abs(local - 0.5);
    float dy = abs(uv.y - 0.5) * 2.0;
    float inside = step(dx, half_width) * smoothstep(level, level - 0.06, dy);
    float4 color = shader.colors[omni_accent];
    return float4(color.rgb, color.a * inside);
}
