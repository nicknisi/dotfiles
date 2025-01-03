// credits: https://github.com/rymdlego

const float speed = 0.2;
const float cube_size = 1.0;
const float cube_brightness = 1.0;
const float cube_rotation_speed = 2.8;
const float camera_rotation_speed = 0.1;



mat3 rotationMatrix(vec3 m,float a) {
    m = normalize(m);
    float c = cos(a),s=sin(a);
    return mat3(c+(1.-c)*m.x*m.x,
        (1.-c)*m.x*m.y-s*m.z,
        (1.-c)*m.x*m.z+s*m.y,
        (1.-c)*m.x*m.y+s*m.z,
        c+(1.-c)*m.y*m.y,
        (1.-c)*m.y*m.z-s*m.x,
        (1.-c)*m.x*m.z-s*m.y,
        (1.-c)*m.y*m.z+s*m.x,
        c+(1.-c)*m.z*m.z);
}

float sphere(vec3 pos, float radius)
{
    return length(pos) - radius;
}

float box(vec3 pos, vec3 size)
{
    float t = iTime;
    pos = pos * 0.9 * rotationMatrix(vec3(sin(t/4.0*speed)*10.,cos(t/4.0*speed)*12.,2.7), t*2.4/4.0*speed*cube_rotation_speed);
    return length(max(abs(pos) - size, 0.0));
}


float distfunc(vec3 pos)
{
    float t = iTime;
    
    float size = 0.45 + 0.25*abs(16.0*sin(t*speed/4.0));
    // float size = 2.3 + 1.8*tan((t-5.4)*6.549);
    size = cube_size * 0.16 * clamp(size, 2.0, 4.0);

    //pos = pos * rotationMatrix(vec3(0.,-3.,0.7), 3.3 * mod(t/30.0, 4.0));
    vec3 q = mod(pos, 5.0) - 2.5;
    float obj1 = box(q, vec3(size));
    return obj1;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    float t = iTime;
    vec2 screenPos = -1.0 + 2.0 * fragCoord.xy / iResolution.xy;
    screenPos.x *= iResolution.x / iResolution.y;
    vec3 cameraOrigin = vec3(t*1.0*speed, 0.0, 0.0);
    // vec3 cameraOrigin = vec3(t*1.8*speed, 3.0+t*0.02*speed, 0.0);
    vec3 cameraTarget = vec3(t*100., 0.0, 0.0);
    cameraTarget = vec3(t*20.0,0.0,0.0) * rotationMatrix(vec3(0.0,0.0,1.0), t*speed*camera_rotation_speed);

    vec3 upDirection = vec3(0.5, 1.0, 0.6);
    
    vec3 cameraDir = normalize(cameraTarget - cameraOrigin);
    vec3 cameraRight = normalize(cross(upDirection, cameraOrigin));
    vec3 cameraUp = cross(cameraDir, cameraRight);
    
    vec3 rayDir = normalize(cameraRight * screenPos.x + cameraUp * screenPos.y + cameraDir);
    
    const int MAX_ITER = 64;
    const float MAX_DIST = 48.0;
    const float EPSILON = 0.001;
    
    float totalDist = 0.0;
    vec3 pos = cameraOrigin;
    float dist = EPSILON;
    
    for (int i = 0; i < MAX_ITER; i++)
    {
        if (dist < EPSILON || totalDist > MAX_DIST)
            break;
        dist = distfunc(pos);
        totalDist += dist;
        pos += dist*rayDir;
    }

    vec4 cubes;

    if (dist < EPSILON)
    {
        // Lighting Code
        vec2 eps = vec2(0.0, EPSILON);
        vec3 normal = normalize(vec3(
            distfunc(pos + eps.yxx) - distfunc(pos - eps.yxx),
            distfunc(pos + eps.xyx) - distfunc(pos - eps.xyx),
            distfunc(pos + eps.xxy) - distfunc(pos - eps.xxy)));
        float diffuse = max(0., dot(-rayDir, normal));
        float specular = pow(diffuse, 32.0);
        vec3 color = vec3(diffuse + specular);
        vec3 cubeColor = vec3(abs(screenPos),0.5+0.5*sin(t*2.0))*0.8;
        cubeColor = mix(cubeColor.rgb, vec3(0.0,0.0,0.0), 1.0);
        color += cubeColor;
        cubes = vec4(color, 1.0) * vec4(1.0 - (totalDist/MAX_DIST));
        cubes = vec4(cubes.rgb*0.02*cube_brightness, 0.1);
    } 
    else {
        cubes = vec4(0.0);
    }

    vec2 uv = fragCoord/iResolution.xy;
    vec4 terminalColor = texture(iChannel0, uv);
    vec3 blendedColor = terminalColor.rgb + cubes.rgb;
    fragColor = vec4(blendedColor, terminalColor.a);
}
