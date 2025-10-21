// Settings for detection
#define TARGET_COLOR vec3(0.0, 0.0, 0.0)      // RGB target pixels to transform
#define REPLACE_COLOR vec3(0.0, 0.0, 0.0)    // Color to replace target pixels
#define COLOR_TOLERANCE 0.001                  // Color matching tolerance

// Smoke effect settings
#define SMOKE_COLOR vec3(1., 1., 1.0)       // Base color of smoke
#define SMOKE_RADIUS 0.011                 // How far the smoke spreads
#define SMOKE_SPEED 0.5                        // Speed of smoke movement
#define SMOKE_SCALE 25.0                       // Scale of smoke detail
#define SMOKE_INTENSITY 0.2                    // Intensity of the smoke effect
#define SMOKE_RISE_HEIGHT 0.14                 // How high the smoke rises
#define ALPHA_MAX 0.5                          // Maximum opacity for smoke
#define VERTICAL_BIAS 1.0       

// Ghost face settings
#define FACE_COUNT 1                           // Number of ghost faces
#define FACE_SCALE vec2(0.03, 0.05)            // Size of faces, can be wider/elongated
#define FACE_DURATION 1.2                      // How long faces last, can be wider/elongated
#define FACE_TRANSITION 1.5                    // Face fade in/out duration
#define FACE_COLOR vec3(0.0, 0.0, 0.0)        
#define GHOST_BG_COLOR vec3(1.0, 1.0, 1.0)    
#define GHOST_BG_SCALE vec2(0.03, 0.06)       

float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

float random1(float n) {
    return fract(sin(n) * 43758.5453123);
}

vec2 random2(float n) {
    return vec2(
        random1(n),
        random1(n + 1234.5678)
    );
}

float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a)* u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// Modified elongated ellipse for more cartoon-like shapes
float cartoonEllipse(vec2 uv, vec2 center, vec2 scale) {
    vec2 d = (uv - center) / scale;
    float len = length(d);
    // Add cartoon-like falloff
    return smoothstep(1.0, 0.8, len);
}

// Function to create ghost background shape
float ghostBackground(vec2 uv, vec2 center) {
    vec2 d = (uv - center) / GHOST_BG_SCALE;
    float baseShape = length(d * vec2(1.0, 0.8)); // Slightly oval
    
    // Add wavy bottom
    float wave = sin(d.x * 6.28 + iTime) * 0.2;
    float bottomWave = smoothstep(0.0, -0.5, d.y + wave);
    
    return smoothstep(1.0, 0.8, baseShape) + bottomWave;
}

float ghostFace(vec2 uv, vec2 center, float time, float seed) {
    vec2 faceUV = (uv - center) / FACE_SCALE;
    
    float eyeSize = 0.25 + random1(seed) * 0.05;
    float eyeSpacing = 0.35;
    vec2 leftEyePos = vec2(-eyeSpacing, 0.2);
    vec2 rightEyePos = vec2(eyeSpacing, 0.2);
    
    float leftEye = cartoonEllipse(faceUV, leftEyePos, vec2(eyeSize));
    float rightEye = cartoonEllipse(faceUV, rightEyePos, vec2(eyeSize));
    
    // Add simple eye highlights
    float leftHighlight = cartoonEllipse(faceUV, leftEyePos + vec2(0.1, 0.1), vec2(eyeSize * 0.3));
    float rightHighlight = cartoonEllipse(faceUV, rightEyePos + vec2(0.1, 0.1), vec2(eyeSize * 0.3));
    
    vec2 mouthUV = faceUV - vec2(0.0, -0.9);
    float mouthWidth = 0.5 + random1(seed + 3.0) * 0.1;
    float mouthHeight = 0.8 + random1(seed + 7.0) * 0.1;
    
    float mouth = cartoonEllipse(mouthUV, vec2(0.0), vec2(mouthWidth, mouthHeight));
    
    // Combine features
    float face = max(max(leftEye, rightEye), mouth);
    face = max(face, max(leftHighlight, rightHighlight));
    
    // Add border falloff
    face *= smoothstep(1.2, 0.8, length(faceUV));
    
    return face;
}

float calculateSmoke(vec2 uv, vec2 sourcePos) {
    float verticalDisp = (uv.y - sourcePos.y) * VERTICAL_BIAS;
    vec2 smokeUV = uv * SMOKE_SCALE;
    smokeUV.y -= iTime * SMOKE_SPEED * (1.0 + verticalDisp);
    smokeUV.x += sin(iTime * 0.5 + uv.y * 4.0) * 0.1;
    
    float n = noise(smokeUV) * 0.5 + 0.5;
    n += noise(smokeUV * 2.0 + iTime * 0.1) * 0.25;
    
    float verticalFalloff = 1.0 - smoothstep(0.0, SMOKE_RISE_HEIGHT, verticalDisp);
    return n * verticalFalloff;
}

float isTargetPixel(vec2 uv) {
    vec4 color = texture(iChannel0, uv);
    return float(all(lessThan(abs(color.rgb - TARGET_COLOR), vec3(COLOR_TOLERANCE))));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord/iResolution.xy;
    vec4 originalColor = texture(iChannel0, uv);
    
    // Calculate smoke effect
    float smokeAccum = 0.0;
    float targetInfluence = 0.0;
    
    float stepSize = SMOKE_RADIUS / 4.0;
    for (float x = -SMOKE_RADIUS; x <= SMOKE_RADIUS; x += stepSize) {
        for (float y = -SMOKE_RADIUS; y <= 0.0; y += stepSize) {
            vec2 offset = vec2(x, y);
            vec2 sampleUV = uv + offset;
            
            if (sampleUV.x >= 0.0 && sampleUV.x <= 1.0 && 
                sampleUV.y >= 0.0 && sampleUV.y <= 1.0) {
                float isTarget = isTargetPixel(sampleUV);
                if (isTarget > 0.0) {
                    float dist = length(offset);
                    float falloff = 1.0 - smoothstep(0.0, SMOKE_RADIUS, dist);
                    float smoke = calculateSmoke(uv, sampleUV);
                    smokeAccum += smoke * falloff;
                    targetInfluence += falloff;
                }
            }
        }
    }
    
    smokeAccum /= max(targetInfluence, 1.0);
    targetInfluence = smoothstep(0.0, 1.0, targetInfluence);
    float smokePresence = smokeAccum * targetInfluence;
    
    // Calculate ghost faces with backgrounds
    float faceAccum = 0.0;
    float bgAccum = 0.0;
    float timeBlock = floor(iTime / FACE_DURATION);
    
    if (smokePresence > 0.2) {
        for (int i = 0; i < FACE_COUNT; i++) {
            vec2 facePos = random2(timeBlock + float(i) * 1234.5);
            facePos = facePos * 0.8 + 0.1;
            
            float faceTime = mod(iTime, FACE_DURATION);
            float fadeFactor = smoothstep(0.0, FACE_TRANSITION, faceTime) * 
                              (1.0 - smoothstep(FACE_DURATION - FACE_TRANSITION, FACE_DURATION, faceTime));
            
            // Add ghost background
            float ghostBg = ghostBackground(uv, facePos) * fadeFactor;
            bgAccum = max(bgAccum, ghostBg);
            
            // Add face features
            float face = ghostFace(uv, facePos, iTime, timeBlock + float(i) * 100.0) * fadeFactor;
            faceAccum = max(faceAccum, face);
        }
        
        bgAccum *= smoothstep(0.2, 0.4, smokePresence);
        faceAccum *= smoothstep(0.2, 0.4, smokePresence);
    }
    
    // Combine all elements
    bool isTarget = all(lessThan(abs(originalColor.rgb - TARGET_COLOR), vec3(COLOR_TOLERANCE)));
    vec3 baseColor = isTarget ? REPLACE_COLOR : originalColor.rgb;
    
    // Layer the effects: base -> smoke -> ghost background -> face features
    vec3 smokeEffect = mix(baseColor, SMOKE_COLOR, smokeAccum * SMOKE_INTENSITY * targetInfluence * (1.0 - faceAccum));
    vec3 withBackground = mix(smokeEffect, GHOST_BG_COLOR, bgAccum * 0.7);
    vec3 finalColor = mix(withBackground, FACE_COLOR, faceAccum);
    
    float alpha = mix(originalColor.a, ALPHA_MAX, max(smokePresence, max(bgAccum, faceAccum) * smokePresence));
    
    fragColor = vec4(finalColor, alpha);
}
