/** Size of TFT "pixels" */
float resolution = 4.0;

/** Strength of effect */
float strength = 0.5;

void _scanline(inout vec3 color, vec2 uv)
{
    float scanline = step(1.2, mod(uv.y * iResolution.y, resolution));
    float grille   = step(1.2, mod(uv.x * iResolution.x, resolution));
    color *= max(1.0 - strength, scanline * grille);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec3 color = texture(iChannel0, uv).rgb;

    _scanline(color, uv);

    fragColor.xyz = color;
    fragColor.w   = 1.0;
}
