
#define TAU 6.28318530718
#define MAX_ITER 6

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec3 water_color = vec3(1.0, 1.0, 1.0) * 0.5;
	float time = iTime * 0.5+23.0;
	vec2 uv = fragCoord.xy / iResolution.xy;

    vec2 p = mod(uv*TAU, TAU)-250.0;
	vec2 i = vec2(p);
	float c = 1.0;
	float inten = 0.005;

	for (int n = 0; n < MAX_ITER; n++)
	{
		float t = time * (1.0 - (3.5 / float(n+1)));
		i = p + vec2(cos(t - i.x) + sin(t + i.y), sin(t - i.y) + cos(t + i.x));
		c += 1.0/length(vec2(p.x / (sin(i.x+t)/inten),p.y / (cos(i.y+t)/inten)));
	}
	c /= float(MAX_ITER);
	c = 1.17-pow(c, 1.4);
	vec3 color = vec3(pow(abs(c), 15.0));
    color = clamp((color + water_color)*1.2, 0.0, 1.0);

    // perterb uv based on value of c from caustic calc above
    vec2 tc = vec2(cos(c)-0.75,sin(c)-0.75)*0.04;
    uv = clamp(uv + tc,0.0,1.0);

    fragColor = texture(iChannel0, uv);
    // give transparent pixels a color
    if ( fragColor.a == 0.0 ) fragColor=vec4(1.0,1.0,1.0,1.0);
    fragColor *= vec4(color, 1.0);
}