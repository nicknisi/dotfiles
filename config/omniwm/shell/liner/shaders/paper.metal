// Liner Notes bar backdrop: paper (light packs) or slate (dark packs) with fine grain, and a dashed
// rule along the bottom like a torn-out page. Static (fps 0). values = (grain, dash ink, -, -).
float paperHash(float2 p) { return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453); }

float4 shade(float2 uv, constant OmniShader& shader) {
    float3 background = shader.colors[omni_background].rgb;
    float3 ink = shader.colors[omni_foreground].rgb;
    bool dark = dot(background, float3(0.299, 0.587, 0.114)) < 0.5;
    float3 paper = dark ? mix(background, ink, 0.07) : background;
    float2 point = uv * shader.size;
    float grain = (paperHash(floor(point * 2.0)) - 0.5) * clamp(shader.values.x, 0.0, 0.3);
    float fiber = (paperHash(float2(floor(point.y * 0.7), 3.0)) - 0.5) * clamp(shader.values.x, 0.0, 0.3) * 0.6;
    float3 color = paper + grain + fiber;
    float fromBottom = (1.0 - uv.y) * shader.size.y;
    float dash = step(fmod(point.x, 9.0), 5.0) * step(0.6, fromBottom) * step(fromBottom, 2.0);
    color = mix(color, ink, dash * clamp(shader.values.y, 0.0, 1.0));
    return float4(color, 1.0);
}
