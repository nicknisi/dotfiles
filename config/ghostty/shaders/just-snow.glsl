// Copyright (c) 2013 Andrew Baldwin (twitter: baldand, www: http://thndl.com)
// License = Attribution-NonCommercial-ShareAlike (http://creativecommons.org/licenses/by-nc-sa/3.0/deed.en_US)

// "Just snow"
// Simple (but not cheap) snow made from multiple parallax layers with randomly positioned 
// flakes and directions. Also includes a DoF effect. Pan around with mouse.

#define LIGHT_SNOW // Comment this out for a blizzard

#ifdef LIGHT_SNOW
	#define LAYERS 50
	#define DEPTH .5
	#define WIDTH .3
	#define SPEED .6
#else // BLIZZARD
	#define LAYERS 200
	#define DEPTH .1
	#define WIDTH .8
	#define SPEED 1.5
#endif

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	const mat3 p = mat3(13.323122,23.5112,21.71123,21.1212,28.7312,11.9312,21.8112,14.7212,61.3934);
	vec2 uv = fragCoord.xy / iResolution.xy;

	vec3 acc = vec3(0.0);
	float dof = 5.0 * sin(iTime * 0.1);
	for (int i = 0; i < LAYERS; i++) {
		float fi = float(i);
		vec2 q =-uv*(1.0 + fi * DEPTH);
		q += vec2(q.y * (WIDTH * mod(fi * 7.238917, 1.0) - WIDTH * 0.5), -SPEED * iTime / (1.0 + fi * DEPTH * 0.03));
		vec3 n = vec3(floor(q), 31.189 + fi);
		vec3 m = floor(n) * 0.00001 + fract(n);
		vec3 mp = (31415.9 + m) / fract(p * m);
		vec3 r = fract(mp);
		vec2 s = abs(mod(q, 1.0) - 0.5 + 0.9 * r.xy - 0.45);
		s += 0.01 * abs(2.0 * fract(10.0 * q.yx) - 1.0); 
		float d = 0.6 * max(s.x - s.y, s.x + s.y) + max(s.x, s.y) - 0.01;
		float edge = 0.005 + 0.05 * min(0.5 * abs(fi - 5.0 - dof), 1.0);
		acc += vec3(smoothstep(edge, -edge, d) * (r.x / (1.0 + 0.02 * fi * DEPTH)));
	}
	
	// Sample the terminal screen texture including alpha channel
	vec4 terminalColor = texture(iChannel0, uv);

	// Combine the snow effect with the terminal color
	vec3 blendedColor = terminalColor.rgb + acc;

	// Use the terminal's original alpha
	fragColor = vec4(blendedColor, terminalColor.a);
}
