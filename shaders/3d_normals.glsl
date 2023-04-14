#define PI 3.1415926538

uniform float iTime;
uniform vec2 iResolution;

mat4 rotationX( in float angle ) {
	return mat4(	1.0,		0,			0,			0,
			 		0, 	cos(angle),	-sin(angle),		0,
					0, 	sin(angle),	 cos(angle),		0,
					0, 			0,			  0, 		1);
}

mat4 rotationY( in float angle ) {
	return mat4(	cos(angle),		0,		sin(angle),	0,
			 				0,		1.0,			 0,	0,
					-sin(angle),	0,		cos(angle),	0,
							0, 		0,				0,	1);
}

mat4 rotationZ( in float angle ) {
	return mat4(	cos(angle),		-sin(angle),	0,	0,
			 		sin(angle),		cos(angle),		0,	0,
							0,				0,		1,	0,
							0,				0,		0,	1);
}

float dot2( in vec2 v ) { return dot(v,v); }
float dot2( in vec3 v ) { return dot(v,v); }
float ndot( in vec2 a, in vec2 b ) { return a.x*b.x - a.y*b.y; }

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

float opSmoothUnion( float d1, float d2, float k ) {
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) - k*h*(1.0-h); 
}

float sdSphere( vec3 p, float s )
{
  return length(p)-s;
}

float sdBox( vec3 p, vec3 b )
{
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float sdTorus( vec3 p, vec2 t )
{
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}

float sdBoxFrame( vec3 p, vec3 b, float e )
{
       p = abs(p  )-b;
  vec3 q = abs(p+e)-e;
  return min(min(
      length(max(vec3(p.x,q.y,q.z),0.0))+min(max(p.x,max(q.y,q.z)),0.0),
      length(max(vec3(q.x,p.y,q.z),0.0))+min(max(q.x,max(p.y,q.z)),0.0)),
      length(max(vec3(q.x,q.y,p.z),0.0))+min(max(q.x,max(q.y,p.z)),0.0));
}

vec3 opTwist(vec3 p )
{
    const float k = 0.05; // or some other amount
    float c = cos(k*p.y);
    float s = sin(k*p.y);
    mat2  m = mat2(c,-s,s,c);
    vec3  q = vec3(m*p.xz,p.y);
    return q;
}

float power = 0.5;

float sceneSDF(vec3 p) {
    float s =0.5;
    float d = sdBox(p, vec3(s, s, s));
    d = min(d, sdSphere(p + vec3(1.5, 0.0, 0.0), 0.5));
    d = min(d, sdTorus(p + vec3(-1.5, 0.0, 0.0), vec2(0.5, 0.2)));
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

void main()
{
    power = (cos(iTime * 0.7) * 0.5) + 0.51;

	vec3 viewDir = rayDirection(70.0, iResolution.xy, gl_FragCoord.xy);
    vec3 eye = cameraPosition;

    vec3 worldDir = (transpose(viewMatrix) * vec4(viewDir, 0)).xyz;

    rayInfo info = getRayInfo(eye, worldDir, MIN_DIST, MAX_DIST);
    float dist = info.shortestDistance;
    float count = info.count;
    float minRadius = info.minRadius;

    if (dist > MAX_DIST - EPSILON) {
        // Didn't hit anything
        float glowTop = 0.05;
        float glowFactor = pow(minRadius, 0.2);
        gl_FragColor = vec4(glowTop / glowFactor, glowTop / glowFactor, glowTop / glowFactor, 1.0);
		return;
    }
    
    float ambientOcclusion;
    ambientOcclusion = pow(count, 2.0) / 4000.0;

    vec3 n =  vec4(estimateNormal(eye + dist * worldDir), 0).xyz;
    gl_FragColor = vec4(n.x * 0.5  + 0.5, n.y * 0.5  + 0.5, n.z * 0.5  + 0.5, 1.0);
}