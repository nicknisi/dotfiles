// Drunken stupor effect using fractal Brownian motion and Perlin noise
// (c) moni-dz (https://github.com/moni-dz) 
// CC BY-NC-SA 4.0 (https://creativecommons.org/licenses/by-nc-sa/4.0/)

vec2 hash2(vec2 p) {
    uvec2 q = uvec2(floatBitsToUint(p.x), floatBitsToUint(p.y));
    q = (q * uvec2(1597334673U, 3812015801U)) ^ (q.yx * uvec2(2798796415U, 1979697793U));
    return vec2(q) * (1.0/float(0xffffffffU)) * 2.0 - 1.0;
}

float perlin2d(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f*f*(3.0-2.0*f);

    return mix(mix(dot(hash2(i + vec2(0.0,0.0)), f - vec2(0.0,0.0)),
                   dot(hash2(i + vec2(1.0,0.0)), f - vec2(1.0,0.0)), u.x),
               mix(dot(hash2(i + vec2(0.0,1.0)), f - vec2(0.0,1.0)),
                   dot(hash2(i + vec2(1.0,1.0)), f - vec2(1.0,1.0)), u.x), u.y);
}

#define OCTAVES 10     // How many passes of fractal Brownian motion to perform
#define GAIN 0.5       // How much should each pixel move
#define LACUNARITY 2.0 // How fast should each ripple be per pass

float fbm(vec2 p) {
    float sum = 0.0;
    float amp = 0.5;
    float freq = 1.0;
    
    for(int i = 0; i < OCTAVES; i++) {
        sum += amp * perlin2d(p * freq);
        freq *= LACUNARITY;
        amp *= GAIN;
    }
    
    return sum;
}


#define NOISE_SCALE 1.0      // How distorted the image you want to be
#define NOISE_INTENSITY 0.05 // How strong the noise effect is
#define ABERRATION true      // Chromatic aberration
#define ABERRATION_DELTA 0.1 // How strong the chromatic aberration effect is
#define ANIMATE true
#define SPEED 0.4            // Animation speed

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord/iResolution.xy;
    float time = ANIMATE ? iTime * SPEED : 0.0;
 
    vec2 noisePos = uv * NOISE_SCALE + vec2(time);
    float noise = fbm(noisePos) * NOISE_INTENSITY;

    vec3 col;

    if (ABERRATION) {
        col.r = texture(iChannel0, uv + vec2(noise * (1.0 + ABERRATION_DELTA))).r;
        col.g = texture(iChannel0, uv + vec2(noise)).g;
        col.b = texture(iChannel0, uv + vec2(noise * (1.0 - ABERRATION_DELTA))).b;
    } else {
        vec2 distortedUV = uv + vec2(noise);
        col = texture(iChannel0, distortedUV).rgb;
    }

    fragColor = vec4(col, 1.0);
}
