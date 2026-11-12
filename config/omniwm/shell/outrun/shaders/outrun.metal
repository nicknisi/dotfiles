// Outrun bar backdrop: a dusk gradient from the pack's background into its purple, a striped synthwave sun
// setting just right of centre, and a neon perspective grid racing toward the horizon.
// values = (grid speed, grid glow, sun size, -). Animated (fps 30).
float4 shade(float2 uv, constant OmniShader& shader) {
    float3 background = shader.colors[omni_background].rgb;
    float3 purple = shader.colors[omni_purple].rgb;
    float3 red = shader.colors[omni_red].rgb;
    float3 yellow = shader.colors[omni_yellow].rgb;
    float3 cyan = shader.colors[omni_teal].rgb;
    float2 size = max(shader.size, float2(1.0));
    float3 color = mix(background * 0.7, mix(background, purple, 0.45), uv.y);

    // The sun: a disc above the horizon, fading yellow to red, with scanline gaps cut into its lower half.
    float horizon = 0.5;
    float2 sunCentre = float2(0.58 * size.x, horizon * size.y);
    float2 delta = uv * size - sunCentre;
    float radius = size.y * clamp(shader.values.z, 0.2, 2.0);
    float disc = 1.0 - smoothstep(radius - 1.0, radius, length(delta));
    float stripes = step(0.0, delta.y + radius * 0.55) * step(0.5, fract((delta.y + radius) / 4.0));
    float sun = disc * step(delta.y, 0.0) * (1.0 - stripes * step(-radius * 0.55, delta.y));
    color = mix(color, mix(yellow, red, clamp((delta.y + radius) / radius, 0.0, 1.0)), sun * 0.85);

    // The grid below the horizon: converging verticals and horizontals rushing toward you.
    if (uv.y > horizon) {
        float depth = (uv.y - horizon) / (1.0 - horizon);           // 0 at horizon, 1 at the bottom edge
        float z = 1.0 / max(depth, 0.02);
        float x = (uv.x - 0.5) * z * 6.0;
        float rows = fract(z * 0.6 + shader.time * clamp(shader.values.x, 0.0, 4.0));
        float vertical = smoothstep(0.86, 1.0, abs(fract(x) - 0.5) * 2.0);   // 1 on a line, 0 between
        float horizontal = smoothstep(0.78, 1.0, abs(rows - 0.5) * 2.0);
        float grid = max(vertical, horizontal) * depth;
        color = mix(color, mix(purple, cyan, 0.4), grid * clamp(shader.values.y, 0.0, 1.0));
    }
    return float4(color, 1.0);
}
