// This Ghostty shader is a port of https://www.shadertoy.com/view/lscGRl

// "Fireworks" by Martijn Steinrucken aka BigWings - 2015
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
// Email:countfrolic@gmail.com Twitter:@The_ArtOfCode

#define BLACK_BLEND_THRESHOLD .4
#define PI 3.141592653589793238
#define TWOPI 6.283185307179586
#define S(x,y,z) smoothstep(x,y,z)
#define B(x,y,z,w) S(x-z, x+z, w)*S(y+z, y-z, w)
#define saturate(x) clamp(x,0.,1.)

#define NUM_EXPLOSIONS 3.
#define NUM_PARTICLES 42.

// Noise functions by Dave Hoskins
#define MOD3 vec3(.1031,.11369,.13787)
vec3 hash31(float p) {
    vec3 p3 = fract(vec3(p) * MOD3);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract(vec3((p3.x + p3.y) * p3.z, (p3.x + p3.z) * p3.y, (p3.y + p3.z) * p3.x));
}
float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * MOD3);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

float circ(vec2 uv, vec2 pos, float size) {
    uv -= pos;

    size *= size;
    return S(size * 1.1, size, dot(uv, uv));
}

float light(vec2 uv, vec2 pos, float size) {
    uv -= pos;

    size *= size;
    return size / dot(uv, uv);
}

vec3 explosion(vec2 uv, vec2 p, float seed, float t) {
    vec3 col = vec3(0.);

    vec3 en = hash31(seed);
    vec3 baseCol = en;
    for (float i = 0.; i < NUM_PARTICLES; i++) {
        vec3 n = hash31(i) - .5;

        vec2 startP = p - vec2(0., t * t * .1);
        vec2 endP = startP + normalize(n.xy) * n.z - vec2(0., t * .2);

        float pt = 1. - pow(t - 1., 2.);
        vec2 pos = mix(p, endP, pt);
        float size = mix(.01, .005, S(0., .1, pt));
        size *= S(1., .1, pt);

        float sparkle = (sin((pt + n.z) * 21.) * .5 + .5);
        sparkle = pow(sparkle, pow(en.x, 3.) * 50.) * mix(0.01, .01, en.y * n.y);

        //size += sparkle*B(.6, 1., .1, t);
        size += sparkle * B(en.x, en.y, en.z, t);

        col += baseCol * light(uv, pos, size);
    }

    return col;
}

vec3 Rainbow(vec3 c) {
    float t = iTime;

    float avg = (c.r + c.g + c.b) / 3.;
    c = avg + (c - avg) * sin(vec3(0., .333, .666) + t);

    c += sin(vec3(.4, .3, .3) * t + vec3(1.1244, 3.43215, 6.435)) * vec3(.4, .1, .5);

    return c;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    uv.x -= .5;
    uv.x *= iResolution.x / iResolution.y;

    // Flip the y-axis so that the gravity is downwards
    uv.y = -uv.y + 1.;

    float n = hash12(uv + 10.);
    float t = iTime * .5;

    vec3 c = vec3(0.);

    for (float i = 0.; i < NUM_EXPLOSIONS; i++) {
        float et = t + i * 1234.45235;
        float id = floor(et);
        et -= id;

        vec2 p = hash31(id).xy;
        p.x -= .5;
        p.x *= 1.6;
        c += explosion(uv, p, id, et);
    }
    c = Rainbow(c);

    vec2 termUV = fragCoord.xy / iResolution.xy;
    vec4 terminalColor = texture(iChannel0, termUV);

    float alpha = step(length(terminalColor.rgb), BLACK_BLEND_THRESHOLD);
    vec3 blendedColor = mix(terminalColor.rgb * 1.0, c.rgb * 0.3, alpha);

    fragColor = vec4(blendedColor, terminalColor.a);
}
