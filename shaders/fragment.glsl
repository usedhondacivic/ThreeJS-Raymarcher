#define PI 3.1415926538

uniform float iTime;
uniform vec2 iResolution;

highp mat4 transpose(in highp mat4 inMatrix) {
    highp vec4 i0 = inMatrix[0];
    highp vec4 i1 = inMatrix[1];
    highp vec4 i2 = inMatrix[2];
    highp vec4 i3 = inMatrix[3];

    highp mat4 outMatrix = mat4(
                 vec4(i0.x, i1.x, i2.x, i3.x),
                 vec4(i0.y, i1.y, i2.y, i3.y),
                 vec4(i0.z, i1.z, i2.z, i3.z),
                 vec4(i0.w, i1.w, i2.w, i3.w)
                 );

    return outMatrix;
}

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

vec4 permute(vec4 x){return mod(((x*34.0)+1.0)*x, 289.0);}
float permute(float x){return floor(mod(((x*34.0)+1.0)*x, 289.0));}
vec4 taylorInvSqrt(vec4 r){return 1.79284291400159 - 0.85373472095314 * r;}
float taylorInvSqrt(float r){return 1.79284291400159 - 0.85373472095314 * r;}

vec4 grad4(float j, vec4 ip){
  const vec4 ones = vec4(1.0, 1.0, 1.0, -1.0);
  vec4 p,s;

  p.xyz = floor( fract (vec3(j) * ip.xyz) * 7.0) * ip.z - 1.0;
  p.w = 1.5 - dot(abs(p.xyz), ones.xyz);
  s = vec4(lessThan(p, vec4(0.0)));
  p.xyz = p.xyz + (s.xyz*2.0 - 1.0) * s.www; 

  return p;
}

float snoise(vec4 v){
  const vec2  C = vec2( 0.138196601125010504,  // (5 - sqrt(5))/20  G4
                        0.309016994374947451); // (sqrt(5) - 1)/4   F4
// First corner
  vec4 i  = floor(v + dot(v, C.yyyy) );
  vec4 x0 = v -   i + dot(i, C.xxxx);

// Other corners

// Rank sorting originally contributed by Bill Licea-Kane, AMD (formerly ATI)
  vec4 i0;

  vec3 isX = step( x0.yzw, x0.xxx );
  vec3 isYZ = step( x0.zww, x0.yyz );
//  i0.x = dot( isX, vec3( 1.0 ) );
  i0.x = isX.x + isX.y + isX.z;
  i0.yzw = 1.0 - isX;

//  i0.y += dot( isYZ.xy, vec2( 1.0 ) );
  i0.y += isYZ.x + isYZ.y;
  i0.zw += 1.0 - isYZ.xy;

  i0.z += isYZ.z;
  i0.w += 1.0 - isYZ.z;

  // i0 now contains the unique values 0,1,2,3 in each channel
  vec4 i3 = clamp( i0, 0.0, 1.0 );
  vec4 i2 = clamp( i0-1.0, 0.0, 1.0 );
  vec4 i1 = clamp( i0-2.0, 0.0, 1.0 );

  //  x0 = x0 - 0.0 + 0.0 * C 
  vec4 x1 = x0 - i1 + 1.0 * C.xxxx;
  vec4 x2 = x0 - i2 + 2.0 * C.xxxx;
  vec4 x3 = x0 - i3 + 3.0 * C.xxxx;
  vec4 x4 = x0 - 1.0 + 4.0 * C.xxxx;

// Permutations
  i = mod(i, 289.0); 
  float j0 = permute( permute( permute( permute(i.w) + i.z) + i.y) + i.x);
  vec4 j1 = permute( permute( permute( permute (
             i.w + vec4(i1.w, i2.w, i3.w, 1.0 ))
           + i.z + vec4(i1.z, i2.z, i3.z, 1.0 ))
           + i.y + vec4(i1.y, i2.y, i3.y, 1.0 ))
           + i.x + vec4(i1.x, i2.x, i3.x, 1.0 ));
// Gradients
// ( 7*7*6 points uniformly over a cube, mapped onto a 4-octahedron.)
// 7*7*6 = 294, which is close to the ring size 17*17 = 289.

  vec4 ip = vec4(1.0/294.0, 1.0/49.0, 1.0/7.0, 0.0) ;

  vec4 p0 = grad4(j0,   ip);
  vec4 p1 = grad4(j1.x, ip);
  vec4 p2 = grad4(j1.y, ip);
  vec4 p3 = grad4(j1.z, ip);
  vec4 p4 = grad4(j1.w, ip);

// Normalise gradients
  vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
  p0 *= norm.x;
  p1 *= norm.y;
  p2 *= norm.z;
  p3 *= norm.w;
  p4 *= taylorInvSqrt(dot(p4,p4));

// Mix contributions from the five corners
  vec3 m0 = max(0.6 - vec3(dot(x0,x0), dot(x1,x1), dot(x2,x2)), 0.0);
  vec2 m1 = max(0.6 - vec2(dot(x3,x3), dot(x4,x4)            ), 0.0);
  m0 = m0 * m0;
  m1 = m1 * m1;
  return 49.0 * ( dot(m0*m0, vec3( dot( p0, x0 ), dot( p1, x1 ), dot( p2, x2 )))
               + dot(m1*m1, vec2( dot( p3, x3 ), dot( p4, x4 ) ) ) ) ;

}

const int MAX_MARCHING_STEPS = 255;
const float MIN_DIST = 0.0;
const float MAX_DIST = 255.0;
const float EPSILON = 0.001;

struct rayInfo
{
    float shortestDistance;
    bool hit;
    float count;
    float minRadius;
};

float sphereSDF(vec3 p, float radius) {
    return length(p) - radius;
}

float boxSDF(vec3 p, vec3 size) {
  vec3 q = abs(p) - size / 2.0;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float power = 8.0;
const int loop_iterations = 50;

vec2 mandleBulbSDF(vec3 position) {
    vec3 z = position;
	float dr = 1.5;
	float r = 0.0;
    int iterations = 0;

	for (int i = 0; i < loop_iterations ; i++) {
        iterations = i;
		r = length(z);

		if (r>2.0) {
            break;
        }
        
		// convert to polar coordinates
		float theta = acos(z.z/r);
		float phi = atan(z.y,z.x);
		dr =  pow( r, power-1.0)*power*dr + 1.0;

		// scale and rotate the point
		float zr = pow( r,power);
		theta = theta*power;
		phi = phi*power;
		
		// convert back to cartesian coordinates
		z = zr*vec3(sin(theta)*cos(phi), sin(phi)*sin(theta), cos(theta));
		z+=position;
	}
    float dst = 0.5*log(r)*r/dr;
	return vec2(iterations, dst*1.0);
}

float torusSDF( vec3 p, vec2 t )
{
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}

float sceneSDF(vec3 samplePoint) {
    float A = 2.0;
    float P = 5.0;
    float sDev = 0.05;
    float triangleWave = 2.0 * acos((1.0 - sDev)*sin((2.0*PI*iTime) / 30.0)) / PI;
    return min(sphereSDF(samplePoint, 3.0), torusSDF((samplePoint.xyzz * rotationZ(0.5)).xyz, vec2(7.0, 0.1))) + snoise(vec4(samplePoint, triangleWave)) * 0.6;
    //return max(-boxSDF(samplePoint, vec3(1, 1, 1)), sphereSDF(samplePoint, 0.55)) + snoise(vec4(samplePoint, iTime / 6.0)) * 0.6;
    //return boxSDF(samplePoint, vec3(3, 3, 3)) + snoise(vec4(samplePoint, iTime / 6.0)) * 0.6;
    //return torusSDF(samplePoint, vec2(3.0, 1.5)) - snoise(vec4(samplePoint, iTime / 6.0)) * 0.6;
    //(mod(samplePoint.x, 2.0) - 1.0
    //samplePoint.x += 2.0;
    //vec4 pointF = vec4(samplePoint.x, samplePoint.y, samplePoint.z, 0);
    //vec4 transformedPoint = pointF * rotationX(-iTime* 0.0) * rotationY(-iTime * 0.0);
    //return mandleBulbSDF(transformedPoint.xyz).y;
    //return mandleBulbSDF(transformedPoint.xyz).y + snoise(vec4(samplePoint, iTime / 6.0)) * 0.01;
    //return snoise(vec4(samplePoint, iTime / 6.0)) * 100.0 + 10.0;
    //return mod(mandleBulbSDF(transformedPoint.xyz).y, 50.0);
    //return mod(samplePoint.x, 10.0);
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
    //power = (cos(iTime * 0.9) * 4.0) + 8.0;

	vec3 viewDir = rayDirection(45.0, iResolution.xy, gl_FragCoord.xy);
    vec3 eye = cameraPosition;

    vec3 worldDir = (transpose(viewMatrix) * vec4(viewDir, 0)).xyz;

    rayInfo info = getRayInfo(eye, worldDir, MIN_DIST, MAX_DIST);
    float dist = info.shortestDistance;
    float count = info.count;
    float minRadius = info.minRadius;

    if (dist > MAX_DIST - EPSILON) {
        // Didn't hit anything
        float glowTop = 0.005;
        float glowFactor = pow(minRadius, 2.0);
        float glow = 1.0 - (glowTop / glowFactor);
        gl_FragColor = vec4((gl_FragCoord.x / iResolution.x) + glow, (gl_FragCoord.y / iResolution.y) + glow, (cos(iTime * 0.8) * 0.4) + 0.6 + glow, 1.0);
        //gl_FragColor = vec4(1.0, 1.0, 1.0, 1.0);
		return;
    }
    
    //gl_FragColor = vec4(10.0/(count*count), 10.0/(count*count), 10.0/(count*count), 1.0);
    float ambientOcclusion;
    /*if(gl_FragCoord.x <= iResolution.x / 3.0){
        ambientOcclusion = pow(count, 2.0) / 3000.0;
        gl_FragColor = vec4(ambientOcclusion, ambientOcclusion, ambientOcclusion, 1.0);
    }else if(gl_FragCoord.x <= iResolution.x * 2.0 / 3.0){
        ambientOcclusion = pow(count, 2.0) / 500.0;
        ambientOcclusion = pow(ambientOcclusion, -1.0);
        gl_FragColor = vec4((gl_FragCoord.x / iResolution.x) - ambientOcclusion, (gl_FragCoord.y / iResolution.y) - ambientOcclusion, (cos(iTime * 1.8) * 0.4) + 0.6 - ambientOcclusion, 1.0);
    }else{*/
        //ambientOcclusion = pow(count, 2.0) / 2000.0;
        //gl_FragColor = vec4((gl_FragCoord.x / iResolution.x) - ambientOcclusion, (gl_FragCoord.y / iResolution.y) - ambientOcclusion, (cos(iTime * 1.8) * 0.4) + 0.6 - ambientOcclusion, 1.0);
    //}

    ambientOcclusion = pow(count,  2.0) / 20.0;
    ambientOcclusion = pow(ambientOcclusion, -1.0);
    ambientOcclusion = 1.0 - ambientOcclusion;
    //ambientOcclusion -= dist / 30.0;
    gl_FragColor = vec4((gl_FragCoord.x / iResolution.x) - ambientOcclusion, (gl_FragCoord.y / iResolution.y) - ambientOcclusion, (cos(iTime * 0.8) * 0.4) + 0.6 - ambientOcclusion, 1.0);
    
    //gl_FragColor = vec4(1.0, 0.0, 0.0, 1.0);
}