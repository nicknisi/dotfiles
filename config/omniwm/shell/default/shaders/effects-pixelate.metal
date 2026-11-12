#define OMNI_TEXTURE
float4 shade(float2 uv, constant OmniShader& shader, texture2d<float> image) {
    float p = omni_progress(shader);
    if (p <= 0.0) return float4(0);
    if (p >= 1.0) return omni_sample(image, uv);
    float2 size = max(shader.size * shader.scale, float2(1));
    float block = max(1.0, shader.values.x * shader.scale * (1.0 - p) * (1.0 - p));
    float2 sampleUV = (floor(uv * size / block) + 0.5) * block / size;
    float4 color = omni_sample(image, clamp(sampleUV, 0.5 / size, 1.0 - 0.5 / size));
    return float4(color.rgb, color.a * p);
}
