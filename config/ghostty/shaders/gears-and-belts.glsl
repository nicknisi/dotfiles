// sligltly modified version of https://www.shadertoy.com/view/DsVSDV
// The only changes are done in the mainImage function 
// Ive added comments on what to modify
// works really well with most colorschemes

#define Rot(a) mat2(cos(a),-sin(a),sin(a),cos(a))
#define antialiasing(n) n/min(iResolution.y,iResolution.x)
#define S(d,b) smoothstep(antialiasing(3.0),b,d)
#define B(p,s) max(abs(p).x-s.x,abs(p).y-s.y)
#define deg45 .707
#define R45(p) (( p + vec2(p.y,-p.x) ) *deg45)
#define Tri(p,s) max(R45(p).x,max(R45(p).y,B(p,s)))
#define DF(a,b) length(a) * cos( mod( atan(a.y,a.x)+6.28/(b*8.0), 6.28/((b*8.0)*0.5))+(b-1.)*6.28/(b*8.0) + vec2(0,11) )

float random (vec2 p) {
    return fract(sin(dot(p.xy, vec2(12.9898,78.233)))* 43758.5453123);
}

float innerGear(vec2 p, float dir){
    p*=Rot(radians(-iTime*45.+45.)*dir);
    vec2 prevP = p;

    //p*=Rot(radians(iTime*45.+20.));
    p = DF(p,7.);
    p-=vec2(0.24);
    p*=Rot(deg45);
    float d = B(p,vec2(0.01,0.06));
    p = prevP;
    float d2 = abs(length(p)-0.42)-0.02;
    d = min(d,d2);
    d2 = abs(length(p)-0.578)-0.02;
    d = min(d,d2);
    d2 = abs(length(p)-0.499)-0.005;
    d = min(d,d2);
    
    p = DF(p,7.);
    p-=vec2(0.43);
    p*=Rot(deg45);
    d2 = B(p,vec2(0.01,0.04));
    d = min(d,d2);
    
    return d;
}

vec3 pattern1(vec2 p, vec3 col, float dir){
    vec2 prevP = p;
    float size = 0.499;
    float thick = 0.15;
    
    p+=vec2(size);
    float d = abs(length(p)-size)-thick;
    d = max(d,innerGear(p,dir));
    col = mix(col,vec3(1.),S(d,0.0));
    
    p = prevP;
    p-=vec2(size);
    d = abs(length(p)-size)-thick;
    d = max(d,innerGear(p,dir));
    col = mix(col,vec3(1.),S(d,0.0));  
    
    return col;
}

vec3 pattern2(vec2 p, vec3 col, float dir){

    vec2 prevP = p;
    float size = 0.33;
    float thick = 0.15;
    float thift = 0.0;
    float speed = 0.3;
    
    p-=vec2(size,0.);
    float d = B(p,vec2(size,thick));
    
    p.x+=thift;
    p.x-=iTime*speed*dir;
    p.x=mod(p.x,0.08)-0.04;
    d = max(d,B(p,vec2(0.011,thick)));
    p = prevP;
    d = max(-(abs(p.y)-0.1),d);
    //d = min(B(p,vec2(1.,0.1)),d);
    p.y=abs(p.y)-0.079;
    d = min(B(p,vec2(1.,0.02)),d);
    
    p = prevP;
    p-=vec2(0.0,size);
    float d2 = B(p,vec2(thick,size));
    
    p.y+=thift;
    p.y+=iTime*speed*dir;
    p.y=mod(p.y,0.08)-0.04;
    d2 = max(d2,B(p,vec2(thick,0.011)));
    
    p = prevP;
    d2 = max(-(abs(p.x)-0.1),d2);
    d2 = min(B(p,vec2(0.005,1.)),d2);
    p.x=abs(p.x)-0.079;
    d2 = min(B(p,vec2(0.02,1.)),d2);    
    
    d = min(d,d2);
    
    p = prevP;
    p+=vec2(0.0,size);
    d2 = B(p,vec2(thick,size));
    
    p.y+=thift;
    p.y-=iTime*speed*dir;
    p.y=mod(p.y,0.08)-0.04;
    d2 = max(d2,B(p,vec2(thick,0.011)));
        
    p = prevP;
    d2 = max(-(abs(p.x)-0.1),d2);
    d2 = min(B(p,vec2(0.005,1.)),d2);
    p.x=abs(p.x)-0.079;
    d2 = min(B(p,vec2(0.02,1.)),d2);   
    
    d = min(d,d2);
    
    p = prevP;
    p+=vec2(size,0.0);
    d2 = B(p,vec2(size,thick));
    
    p.x+=thift;
    p.x+=iTime*speed*dir;
    p.x=mod(p.x,0.08)-0.04;
    d2 = max(d2,B(p,vec2(0.011,thick)));
    d = min(d,d2);    
    p = prevP;
    d = max(-(abs(p.y)-0.1),d);
    d = min(B(p,vec2(1.,0.005)),d);
    p.y=abs(p.y)-0.079;
    d = min(B(p,vec2(1.,0.02)),d);    
    
    p = prevP;
    d2 = abs(B(p,vec2(size*0.3)))-0.05;
    d = min(d,d2); 
    
    col = mix(col,vec3(1.),S(d,0.0));
    
    d = B(p,vec2(0.08));
    col = mix(col,vec3(0.),S(d,0.0));
    
    p*=Rot(radians(60.*iTime*dir));
    d = B(p,vec2(0.03));
    col = mix(col,vec3(1.),S(d,0.0));     
     
    return col;
}

vec3 drawBelt(vec2 p, vec3 col, float size){
    vec2 prevP = p;
    
    p*=size;
    vec2 id = floor(p);
    vec2 gr = fract(p)-0.5;
    float dir = mod(id.x+id.y,2.)*2.-1.;
    float n = random(id);
    
    if(n<0.5){
        if(n<0.25){
            gr.x*=-1.;
        }
        col = pattern1(gr,col,dir);
    } else {
        if(n>0.75){
            gr.x*=-1.;
        }
        col = pattern2(gr,col,dir);
    }
    
    return col;
}

vec3 gear(vec2 p, vec3 col, float dir){
    vec2 prevP = p;

    p*=Rot(radians(iTime*45.+13.)*-dir);
    p = DF(p,7.);
    p-=vec2(0.23);
    p*=Rot(deg45);
    float d = B(p,vec2(0.01,0.04));
    p = prevP;
    float d2 = abs(length(p)-0.29)-0.02;
    d = min(d,d2);
    col = mix(col,vec3(1.),S(d,0.0));
    
    p*=Rot(radians(iTime*30.-30.)*dir);
    p = DF(p,6.);
    p-=vec2(0.14);
    p*=Rot(radians(45.));
    d = B(p,vec2(0.01,0.03));
    p = prevP;
    d2 =abs( length(p)-0.1)-0.02;
    p*=Rot(radians(iTime*25.+30.)*-dir);
    d2 = max(-(abs(p.x)-0.05),d2);
    d = min(d,d2);
    col = mix(col,vec3(1.),S(d,0.0));
    
    return col;
}

vec3 item0(vec2 p, vec3 col, float dir){
    vec2 prevP = p;
    p.x*=dir;
    p*=Rot(radians(iTime*30.+30.));
    float d = abs(length(p)-0.2)-0.05;
    col = mix(col,vec3(0.3),S(d,0.0));
    
    d = abs(length(p)-0.2)-0.05;
    d = max(-p.x,d);
    float a = clamp(atan(p.x,p.y)*0.5,0.3,1.);
    
    col = mix(col,vec3(a),S(d,0.0));
    
    return col;
}


vec3 item1(vec2 p, vec3 col, float dir){
    p.x*=dir;
    vec2 prevP = p;
    p*=Rot(radians(iTime*30.+30.));
    float d = abs(length(p)-0.25)-0.04;
    d = abs(max((abs(p.y)-0.15),d))-0.005;
    float d2 = abs(length(p)-0.25)-0.01;
    d2 = max((abs(p.y)-0.12),d2);
    d = min(d,d2);
    
    d2 = abs(length(p)-0.27)-0.01;
    d2 = max(-(abs(p.y)-0.22),d2);
    d = min(d,d2);
    d2 = B(p,vec2(0.01,0.32));
    d2 = max(-(abs(p.y)-0.22),d2);
    d = min(d,d2);
    
    p = prevP;
    p*=Rot(radians(iTime*-20.+30.));
    p = DF(p,2.);
    p-=vec2(0.105);
    p*=Rot(radians(45.));
    d2 = B(p,vec2(0.03,0.01));
    d = min(d,d2);
    
    p = prevP;
    d2 = abs(length(p)-0.09)-0.005;
    d2 = max(-(abs(p.x)-0.03),d2);
    d2 = max(-(abs(p.y)-0.03),d2);
    d = min(d,d2);
    
    col = mix(col,vec3(0.6),S(d,0.0));
    
    return col;
}

vec3 item2(vec2 p, vec3 col, float dir){
    p.x*=dir;
    p*=Rot(radians(iTime*50.-10.));
    vec2 prevP = p;
    float d = abs(length(p)-0.15)-0.005;
    float d2 =  abs(length(p)-0.2)-0.01;
    d2 = max((abs(p.y)-0.15),d2);
    d = min(d,d2);
    
    p = DF(p,1.);
    p-=vec2(0.13);
    p*=Rot(radians(45.));
    d2 = B(p,vec2(0.008,0.1));
    d = min(d,d2);    
    
    p = prevP;
    p = DF(p,4.);
    p-=vec2(0.18);
    p*=Rot(radians(45.));
    d2 = B(p,vec2(0.005,0.02));
    d = min(d,d2);   
    
    col = mix(col,vec3(0.6),S(d,0.0));
    
    return col;
}

float needle(vec2 p){
    p.y-=0.05;
    p*=1.5;
    vec2 prevP = p;
    p.y-=0.3;
    p.x*=6.;
    float d = Tri(p,vec2(0.3));
    p = prevP;
    p.y+=0.1;
    p.x*=2.;
    p.y*=-1.;
    float d2 = Tri(p,vec2(0.1));
    d = min(d,d2);
    return d;
}

vec3 item3(vec2 p, vec3 col, float dir){
    
    p*=Rot(radians(sin(iTime*dir)*120.));
    vec2 prevP = p;
   
    p.y= abs(p.y)-0.05;
    float d = needle(p);
    p = prevP;
    float d2 = abs(length(p)-0.1)-0.003;
    d2 = max(-(abs(p.x)-0.05),d2);
    d = min(d,d2);
    d2 = abs(length(p)-0.2)-0.005;
    d2 = max(-(abs(p.x)-0.08),d2);
    d = min(d,d2);
    
    p = DF(p,4.);
    p-=vec2(0.18);
    d2 = length(p)-0.01;
    p = prevP;
    d2 = max(-(abs(p.x)-0.03),d2);
    d = min(d,d2);   
    
    col = mix(col,vec3(0.6),S(d,0.0));
    
    return col;
}

vec3 drawGearsAndItems(vec2 p, vec3 col, float size){
    vec2 prevP = p;
    p*=size;
    p+=vec2(0.5);
    
    vec2 id = floor(p);
    vec2 gr = fract(p)-0.5;
    
    float n = random(id);
    float dir = mod(id.x+id.y,2.)*2.-1.;
    if(n<0.3){
        col = gear(gr,col,dir);
    } else if(n>=0.3 && n<0.5){
        col = item0(gr,col,dir);
    } else if(n>=0.5 && n<0.7){
        col = item1(gr,col,dir);
    } else if(n>=0.7 && n<0.8) {
        col = item2(gr,col,dir);
    } else if(n>=0.8){
        col = item3(gr,col,dir);
    }
    
    return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 p = (fragCoord-0.5*iResolution.xy)/iResolution.y;
    // set speed of downwards motion
    p.y+=iTime*0.02;
    
    float size = 4.;
    vec3 col = vec3(0.);
    
    // Modify the colors to be darker by multiplying with a small factor
    vec3 darkFactor = vec3(.5); // This makes everything 50% as bright
    
    // Get the original colors but make them darker
    col = drawBelt(p, col, size) * darkFactor;
    col = drawGearsAndItems(p, col, size) * darkFactor;
    
    // Additional option: you can add a color tint to make it less stark white
    vec3 tint = vec3(0.1, 0.12, 0.15); // Slight blue-ish dark tint
    col = col * tint;
    
    vec2 uv = fragCoord/iResolution.xy;
    vec4 terminalColor = texture(iChannel0, uv);
    
    // Blend with reduced opacity for the shader elements
    vec3 blendedColor = terminalColor.rgb + col.rgb * 0.7; // Reduced blend factor
    
    fragColor = vec4(blendedColor, terminalColor.a);
}
