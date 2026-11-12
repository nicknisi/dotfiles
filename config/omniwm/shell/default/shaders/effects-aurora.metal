float4 shade(float2 uv, constant OmniShader& shader) {
    float strength = clamp(shader.values.x, 0.0, 1.0);
    float time = shader.time * shader.values.y;
    float x = uv.x * 8.0 + sin(uv.y * 3.0 - time * 0.5) * 0.9;
    float ribbon = pow(0.5 + 0.5 * sin(x + time * 0.35), 4.0);
    float detail = pow(0.5 + 0.5 * sin(x * 1.7 - time * 0.6), 8.0);
    float light = (ribbon * 0.7 + detail * 0.3) * (0.35 + 0.65 * sin(uv.y * M_PI_F));
    float blend = 0.5 + 0.5 * sin(x * 0.45 + time * 0.15);
    float4 color = mix(shader.colors[omni_accent], shader.colors[omni_purple], blend);
    return float4(color.rgb, clamp(light * strength * color.a, 0.0, 1.0));
}
