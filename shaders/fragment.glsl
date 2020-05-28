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
	float dr = 1.50;
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

float sceneSDF(vec3 samplePoint) {
    //return sphereSDF(samplePoint, 1);
    //return max(-boxSDF(samplePoint, vec3(1, 1, 1)), sphereSDF(samplePoint, 0.55));
    //return boxSDF(samplePoint, vec3(1, 1, 1));
    //(mod(samplePoint.x, 2.0) - 1.0
    samplePoint.x += 2.0;
    vec4 pointF = vec4(mod(samplePoint.x, 4.0) - 2.0, samplePoint.y, samplePoint.z, 0);
    vec4 transformedPoint = pointF * rotationX(-iTime* 0.5) * rotationY(-iTime * 0.9);
    return mandleBulbSDF(transformedPoint.xyz).y;
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
    power = (cos(iTime) * 4.0) + 8.0;

	vec3 viewDir = rayDirection(45.0, iResolution.xy, gl_FragCoord.xy);
    vec3 eye = cameraPosition;

    vec3 worldDir = (transpose(viewMatrix) * vec4(viewDir, 0)).xyz;

    rayInfo info = getRayInfo(eye, worldDir, MIN_DIST, MAX_DIST);
    float dist = info.shortestDistance;
    float count = info.count;
    float minRadius = info.minRadius;

    
    if (dist > MAX_DIST - EPSILON) {
        // Didn't hit anything
        float glowTop = 0.05;
        float glowFactor = pow(minRadius, 0.5);
        gl_FragColor = vec4(glowTop / glowFactor, glowTop / glowFactor, glowTop / glowFactor, 1.0);
        //gl_FragColor = vec4(0.0, 1.0, 0.0, 1.0);
		return;
    }
    
    //gl_FragColor = vec4(10.0/(count*count), 10.0/(count*count), 10.0/(count*count), 1.0);
    float ambientOcclusion;
    if(gl_FragCoord.x <= iResolution.x / 3.0){
        ambientOcclusion = pow(count, 2.0) / 3000.0;
        gl_FragColor = vec4(ambientOcclusion, ambientOcclusion, ambientOcclusion, 1.0);
    }else if(gl_FragCoord.x <= iResolution.x * 2.0 / 3.0){
        ambientOcclusion = pow(count, 2.0) / 500.0;
        ambientOcclusion = pow(ambientOcclusion, -1.0);
        gl_FragColor = vec4((gl_FragCoord.x / iResolution.x) - ambientOcclusion, (gl_FragCoord.y / iResolution.y) - ambientOcclusion, (cos(iTime * 1.5) * 0.4) + 0.6 - ambientOcclusion, 1.0);
    }else{
        ambientOcclusion = pow(count, 2.0) / 2000.0;
        gl_FragColor = vec4((gl_FragCoord.x / iResolution.x) - ambientOcclusion, (gl_FragCoord.y / iResolution.y) - ambientOcclusion, (cos(iTime * 1.5) * 0.4) + 0.6 - ambientOcclusion, 1.0);
    }
    
    //gl_FragColor = vec4(1.0, 0.0, 0.0, 1.0);
}