// adapted by Alex Sherwin for Ghostty from https://www.shadertoy.com/view/lljGDt

#define BLACK_BLEND_THRESHOLD .4

float hash21(vec2 p) {
    p = fract(p * vec2(233.34, 851.73));
    p += dot(p, p + 23.45);
    return fract(p.x * p.y);
}

float rayStrength(vec2 raySource, vec2 rayRefDirection, vec2 coord, float seedA, float seedB, float speed)
{
    vec2 sourceToCoord = coord - raySource;
    float cosAngle = dot(normalize(sourceToCoord), rayRefDirection);
    
    // Add subtle dithering based on screen coordinates
    float dither = hash21(coord) * 0.015 - 0.0075;
    
    float ray = clamp(
        (0.45 + 0.15 * sin(cosAngle * seedA + iTime * speed)) +
        (0.3 + 0.2 * cos(-cosAngle * seedB + iTime * speed)) + dither,
        0.0, 1.0);
        
    // Smoothstep the distance falloff
    float distFade = smoothstep(0.0, iResolution.x, iResolution.x - length(sourceToCoord));
    return ray * mix(0.5, 1.0, distFade);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 uv = fragCoord.xy / iResolution.xy;

	uv.y = 1.0 - uv.y;
	vec2 coord = vec2(fragCoord.x, iResolution.y - fragCoord.y);
	
	// Set the parameters of the sun rays
	vec2 rayPos1 = vec2(iResolution.x * 0.7, iResolution.y * 1.1);
	vec2 rayRefDir1 = normalize(vec2(1.0, 0.116));
	float raySeedA1 = 36.2214;
	float raySeedB1 = 21.11349;
	float raySpeed1 = 1.1;
	
	vec2 rayPos2 = vec2(iResolution.x * 0.8, iResolution.y * 1.2);
	vec2 rayRefDir2 = normalize(vec2(1.0, -0.241));
	const float raySeedA2 = 22.39910;
	const float raySeedB2 = 18.0234;
	const float raySpeed2 = 0.9;
	
	// Calculate the colour of the sun rays on the current fragment
	vec4 rays1 =
		vec4(1.0, 1.0, 1.0, 0.0) *
		rayStrength(rayPos1, rayRefDir1, coord, raySeedA1, raySeedB1, raySpeed1);
	 
	vec4 rays2 =
		vec4(1.0, 1.0, 1.0, 0.0) *
		rayStrength(rayPos2, rayRefDir2, coord, raySeedA2, raySeedB2, raySpeed2);
	
	vec4 col = rays1 * 0.5 + rays2 * 0.4;
	
	// Attenuate brightness towards the bottom, simulating light-loss due to depth.
	// Give the whole thing a blue-green tinge as well.
	float brightness = 1.0 - (coord.y / iResolution.y);
	col.r *= 0.05 + (brightness * 0.8);
	col.g *= 0.15 + (brightness * 0.6);
	col.b *= 0.3 + (brightness * 0.5);

  vec2 termUV = fragCoord.xy / iResolution.xy;
  vec4 terminalColor = texture(iChannel0, termUV);

  float alpha = step(length(terminalColor.rgb), BLACK_BLEND_THRESHOLD);
  vec3 blendedColor = mix(terminalColor.rgb * 1.0, col.rgb * 0.3, alpha);
  
  fragColor = vec4(blendedColor, terminalColor.a);
}
