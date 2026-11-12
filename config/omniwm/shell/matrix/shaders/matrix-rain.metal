constant uint matrixGlyphs[16] = {
    0x1d19d72eu, 0x1c4210c4u, 0x3e10ba0fu, 0x1f083a0fu,
    0x10847d29u, 0x1f083c3fu, 0x1d18bc3eu, 0x0422221fu,
    0x1d18ba2eu, 0x1f0f462eu, 0x0222329fu, 0x154a53e4u,
    0x095713e4u, 0x02222630u, 0x0957111fu, 0x04444231u
};

uint matrixHash(uint value) {
    value ^= value >> 16;
    value *= 0x7feb352du;
    value ^= value >> 15;
    value *= 0x846ca68bu;
    return value ^ (value >> 16);
}

float4 shade(float2 uv, constant OmniShader& shader) {
    float strength = clamp(shader.values.x, 0.0, 1.0);
    float time = shader.time * clamp(shader.values.y, 0.0, 4.0);
    float cellSize = clamp(shader.values.z, 6.0, 40.0);
    float bar = clamp(shader.values.w, 0.0, 1.0);
    float2 grid = uv * max(shader.size, float2(1.0)) / float2(cellSize, cellSize * 1.3);
    uint2 cell = uint2(floor(grid));
    float2 local = fract(grid);
    uint hash = matrixHash(cell.x + 7u);
    float seed = float(hash & 65535u) / 65535.0;
    float rows = shader.size.y / (cellSize * 1.3);
    float head = fmod(time * (2.2 + seed * 3.0) + seed * 80.0, rows + 14.0);
    float distance = head - float(cell.y);
    float trail = step(0.0, distance) * exp(-max(distance, 0.0) * 0.24) * step(0.16, seed);
    float hot = step(0.0, distance) * step(distance, 1.2);
    uint phase = uint(floor(time * 0.7 + seed * 2.0));
    uint character = matrixHash(cell.x * 73u + cell.y * 137u + phase) & 15u;
    float2 pixel = local * float2(7.0, 8.0) - 1.0;
    uint2 bit = uint2(clamp(floor(pixel), float2(0.0), float2(4.0, 5.0)));
    float mask = float((matrixGlyphs[character] >> (bit.y * 5u + bit.x)) & 1u);
    float2 inside = step(float2(0.0), pixel) * (1.0 - step(float2(5.0, 6.0), pixel));
    float2 point = fract(pixel);
    float2 antialias = max(fwidth(pixel), float2(0.001));
    float2 ink = smoothstep(float2(0.0), antialias, point)
        * (1.0 - smoothstep(float2(0.86) - antialias, float2(0.86), point));
    float glyph = mask * inside.x * inside.y * ink.x * ink.y;
    float faint = 0.08 + 0.07 * float(matrixHash(cell.x * 2u + cell.y) & 255u) / 255.0;
    float3 phosphor = mix(shader.colors[omni_accent].rgb, shader.colors[omni_foreground].rgb, hot * 0.8);
    float3 color = mix(shader.colors[omni_background].rgb, shader.colors[omni_surface].rgb, 0.16);
    color += phosphor * glyph * (trail * 0.93 + faint) * strength;
    float sweep = exp(-pow((uv.x - fract(time * 0.055)) * 9.0, 2.0));
    color += shader.colors[omni_accent].rgb * sweep * bar * strength * 0.075;
    float scanline = 1.0 - 0.045 * step(0.72, fract(uv.y * shader.size.y / 3.0));
    return float4(clamp(color * scanline, 0.0, 1.0), 1.0);
}
