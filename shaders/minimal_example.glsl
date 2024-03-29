#define PI 3.1415926538

uniform vec2 iResolution;

const int MAX_MARCHING_STEPS = 255;
const float MIN_DIST = 0.0;
const float MAX_DIST = 700.0;
const float EPSILON = 0.0001;

struct rayInfo
{
    float shortestDistance;
    bool hit;
    float count;
    float minRadius;
};

float sdTorus( vec3 p, vec2 t )
{
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}


float sceneSDF(vec3 p) {
    float d = sdTorus(p, vec2(1.0, 0.3));
    return d;
}

float shortestDistanceToSurface(vec3 eye, vec3 marchingDirection, float start, float end) {
    float depth = start;
    for (int i = 0; i < MAX_MARCHING_STEPS; i++) {
        float dist = sceneSDF(eye + depth * marchingDirection);
        if (dist < EPSILON) {
			return depth;
        }
        depth += dist;
        if (depth >= end) {
            return end;
        }
    }
    return end;
}

rayInfo getRayInfo(vec3 eye, vec3 marchingDirection, float start, float end) {
    float depth = start;
    float minRadius = 10000.0;
    for (int i = 0; i < MAX_MARCHING_STEPS; i++) {
        float dist = sceneSDF(eye + depth * marchingDirection);
        if(dist < minRadius){minRadius = dist;}
        if (dist < EPSILON) {
			return rayInfo(depth, true, float(i), minRadius);
        }
        depth += dist;
        if (depth >= end) {
            return rayInfo(end, false, float(i), minRadius);
        }
    }
    return rayInfo(end, false, float(MAX_MARCHING_STEPS), minRadius);
}
            
vec3 rayDirection(float fieldOfView, vec2 size, vec2 fragCoord) {
    vec2 xy = fragCoord - size / 2.0;
    float z = size.y / tan(radians(fieldOfView) / 2.0);
    return normalize(vec3(xy, -z));
}

vec3 estimateNormal(vec3 p) {
    return normalize(vec3(
        sceneSDF(vec3(p.x + EPSILON, p.y, p.z)) - sceneSDF(vec3(p.x - EPSILON, p.y, p.z)),
        sceneSDF(vec3(p.x, p.y + EPSILON, p.z)) - sceneSDF(vec3(p.x, p.y - EPSILON, p.z)),
        sceneSDF(vec3(p.x, p.y, p.z  + EPSILON)) - sceneSDF(vec3(p.x, p.y, p.z - EPSILON))
    ));
}

float diffuseLight(vec3 p, vec3 lightPos){
    // https://timcoster.com/2020/02/11/raymarching-shader-pt1-glsl/
    vec3 l = normalize(lightPos-p); // Light Vector
    vec3 n = estimateNormal(p); // Normal Vector
   
    float dif = dot(n,l); // Diffuse light
    dif = clamp(dif,0.,1.); // Clamp so it doesnt go below 0
 
    return dif;
}

void main()
{
	vec3 viewDir = rayDirection(70.0, iResolution.xy, gl_FragCoord.xy);
    vec3 eye = cameraPosition;
    vec3 worldDir = (transpose(viewMatrix) * vec4(viewDir, 0)).xyz;

    rayInfo info = getRayInfo(eye, worldDir, MIN_DIST, MAX_DIST);
    float dist = info.shortestDistance;
    float count = info.count;
    float minRadius = info.minRadius;

    if (dist > MAX_DIST - EPSILON) {
        // Didn't hit anything
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
		return;
    }

    vec3 collisionPoint = eye + dist * worldDir;
    float redLight = diffuseLight(collisionPoint, vec3(2.0, 2.0, 2.0)) * 1.5;
    float greenLight = diffuseLight(collisionPoint, vec3(-2.0, 2.0, 2.0)) * 1.5;
    float blueLight = diffuseLight(collisionPoint, vec3(2.0, 2.0, -2.0)) * 1.5;
    float whiteLight = diffuseLight(collisionPoint, vec3(-2.0, -2.0, -2.0)) * 1.5;
    float ambientOcclusion = -pow(count, 2.0) / 3000.0;
    
    gl_FragColor = vec4(redLight + whiteLight + ambientOcclusion + 0.1, greenLight + whiteLight + ambientOcclusion + 0.1,  blueLight  + whiteLight+ ambientOcclusion + 0.1, 1.0);
}