#define OMNI_TEXTURE
float4 shade(float2 uv, constant OmniShader& shader, texture2d<float> image) {
    float p = omni_progress(shader);
    if (p <= 0.0) return float4(0);
    if (p >= 1.0) return omni_sample(image, uv);
    float y = shader.values.y > 0.5 ? 1.0 - uv.y : uv.y;
    float v = (y - (1.0 - p)) / p;
    if (v < 0.0 || v > 1.0) return float4(0);
    float width = p * (1.0 - (1.0 - p) * v * v);
    float bend = p + p * (1.0 - p) * (1.0 - v) * (1.0 - v);
    float center = mix(clamp(shader.values.x, 0.0, 1.0), 0.5, bend);
    float u = (uv.x - center) / width + 0.5;
    if (u < 0.0 || u > 1.0) return float4(0);
    return omni_sample(image, float2(u, shader.values.y > 0.5 ? 1.0 - v : v));
}
