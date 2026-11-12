// Prairie Sky bar backdrop, painted from the theme pack: dark packs get a dusk sky running from deep
// blue through purple and red to a gold glow on the right, with twinkling stars; light packs get a
// soft morning sky. Clouds drift slowly. (shader.time is seconds since the shader started, so this
// can't follow the real clock; the prairie widget carries the live sun, weather and wind.)
// values = (cloud amount, drift speed, star amount, darken for legibility).
float skyHash(float2 p) { return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453); }

float skyNoise(float2 p) {
    float2 cell = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = skyHash(cell), b = skyHash(cell + float2(1, 0));
    float c = skyHash(cell + float2(0, 1)), d = skyHash(cell + float2(1, 1));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float4 shade(float2 uv, constant OmniShader& shader) {
    float3 background = shader.colors[omni_background].rgb;
    float3 blue = shader.colors[omni_blue].rgb;
    float3 purple = shader.colors[omni_purple].rgb;
    float3 red = shader.colors[omni_red].rgb;
    float3 yellow = shader.colors[omni_yellow].rgb;
    float3 ink = shader.colors[omni_foreground].rgb;
    bool dark = dot(background, float3(0.299, 0.587, 0.114)) < 0.5;
    float x = uv.x;
    float3 sky;
    if (dark) {
        sky = mix(mix(background, blue, 0.35), purple, smoothstep(0.05, 0.6, x));
        sky = mix(sky, red, smoothstep(0.55, 0.88, x) * 0.75);
        sky = mix(sky, yellow, smoothstep(0.86, 1.0, x) * 0.65);
        sky *= mix(1.0, 0.82, uv.y < 0.5 ? 1.0 - uv.y * 2.0 : 0.0); // a darker zenith
    } else {
        sky = mix(mix(background, blue, 0.28), mix(background, yellow, 0.35), smoothstep(0.0, 1.0, x));
    }
    float2 point = uv * shader.size;
    float drift = shader.time * clamp(shader.values.y, 0.0, 4.0);
    float cloud = skyNoise(float2(point.x * 0.012 + drift * 0.02, point.y * 0.09))
        * 0.65 + skyNoise(float2(point.x * 0.03 - drift * 0.01, point.y * 0.2)) * 0.35;
    sky = mix(sky, dark ? ink : float3(1.0), smoothstep(0.55, 0.85, cloud) * clamp(shader.values.x, 0.0, 1.0));
    if (dark) {
        float2 cell = floor(point / 6.0);
        float star = step(0.985, skyHash(cell)) * (1.0 - smoothstep(0.35, 0.7, x));
        float twinkle = 0.55 + 0.45 * sin(shader.time * 2.0 + skyHash(cell + 7.0) * 30.0);
        float2 local = fract(point / 6.0) - 0.5;
        sky = mix(sky, ink, star * twinkle * smoothstep(0.18, 0.0, length(local)) * clamp(shader.values.z, 0.0, 1.0));
    }
    sky *= 1.0 - clamp(shader.values.w, 0.0, 0.6);
    return float4(sky, 1.0);
}
