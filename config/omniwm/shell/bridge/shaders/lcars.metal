// Bridge (LCARS) bar backdrop: a black console, an orange elbow sweeping from the left end into a strip
// along the bottom, and that strip broken into colored segments like a starship panel.
// values = (elbow width, elbow inner radius, -, -). Static (fps 0).
float4 shade(float2 uv, constant OmniShader& shader) {
    float3 orange = shader.colors[omni_orange].rgb;
    float3 purple = shader.colors[omni_purple].rgb;
    float3 blue = shader.colors[omni_blue].rgb;
    float2 size = max(shader.size, float2(1.0));
    float2 p = uv * size;
    float elbow = clamp(shader.values.x, 20.0, 200.0);
    float inner = clamp(shader.values.y, 2.0, 40.0);
    float strip = 5.0;                                   // height of the bottom strip
    float3 color = float3(0.0);
    // The elbow: a left block plus the bottom strip, with a concave inner corner where they meet.
    bool inBlock = p.x < elbow;
    bool inStrip = p.y > size.y - strip;
    float2 corner = float2(elbow + inner, size.y - strip - inner);
    bool cut = p.x > elbow && p.y < size.y - strip && p.x < corner.x && p.y > corner.y
        && length(p - corner) > inner;
    bool outerRound = p.x < 18.0 && p.y > size.y - 18.0 && length(p - float2(18.0, size.y - 18.0)) > 18.0;
    if ((inBlock || inStrip || cut) && !outerRound) {
        // the strip past the elbow is broken into segments with black gaps, cycling purple / blue / orange
        float segment = floor((p.x - elbow) / 160.0);
        float gap = step(fmod(max(p.x - elbow, 0.0), 160.0), 4.0) * step(elbow + 40.0, p.x);
        float3 hue = p.x < elbow + 40.0 ? orange : (fmod(segment, 3.0) < 1.0 ? purple : (fmod(segment, 3.0) < 2.0 ? blue : orange));
        color = mix(hue, float3(0.0), gap);
    }
    return float4(color, 1.0);
}
