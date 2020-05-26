uniform float iTime;
uniform vec2 iResolution;

/**
 * Part 2 Challenges
 * - Change the diffuse color of the sphere to be blue
 * - Change the specual color of the sphere to be green
 * - Make one of the lights pulse by having its intensity vary over time
 * - Add a third light to the scene
 */

const int MAX_MARCHING_STEPS = 255;
const float MIN_DIST = 0.0;
const float MAX_DIST = 1000.0;
const float EPSILON = 0.0001;

struct rayInfo
{
    float shortestDistance;
    bool hit;
    float count;
    float minRadius;
};

/**
 * Signed distance function for a sphere centered at the origin;
 */
float sphereSDF(vec3 p, float radius) {
    return length(p) - radius;
}

float boxSDF(vec3 p, vec3 size) {
  vec3 q = abs(p) - size / 2.0;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

/**
 * Signed distance function describing the scene.
 * 
 * Absolute value of the return value indicates the distance to the surface.
 * Sign indicates whether the point is inside or outside the surface,
 * negative indicating inside.
 */
float sceneSDF(vec3 samplePoint) {
    //return sphereSDF(samplePoint, 1);
    //return max(-boxSDF(samplePoint, vec3(1, 1, 1)), sphereSDF(samplePoint, 0.55));
    return boxSDF(samplePoint, vec3(1, 1, 1));
}

/**
 * Return the shortest distance from the eyepoint to the scene surface along
 * the marching direction. If no part of the surface is found between start and end,
 * return end.
 * 
 * eye: the eye point, acting as the origin of the ray
 * marchingDirection: the normalized direction to march in
 * start: the starting distance away from the eye
 * end: the max distance away from the ey to march before giving up
 */
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
            

/**
 * Return the normalized direction to march in from the eye point for a single pixel.
 * 
 * fieldOfView: vertical field of view in degrees
 * size: resolution of the output image
 * fragCoord: the x,y coordinate of the pixel in the output image
 */
vec3 rayDirection(float fieldOfView, vec2 size, vec2 fragCoord) {
    vec2 xy = fragCoord - size / 2.0;
    float z = size.y / tan(radians(fieldOfView) / 2.0);
    return normalize(vec3(xy, -z));
}

/**
 * Using the gradient of the SDF, estimate the normal on the surface at point p.
 */
vec3 estimateNormal(vec3 p) {
    return normalize(vec3(
        sceneSDF(vec3(p.x + EPSILON, p.y, p.z)) - sceneSDF(vec3(p.x - EPSILON, p.y, p.z)),
        sceneSDF(vec3(p.x, p.y + EPSILON, p.z)) - sceneSDF(vec3(p.x, p.y - EPSILON, p.z)),
        sceneSDF(vec3(p.x, p.y, p.z  + EPSILON)) - sceneSDF(vec3(p.x, p.y, p.z - EPSILON))
    ));
}

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

void main()
{
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
		return;
    }
    
    //gl_FragColor = vec4(10.0/(count*count), 10.0/(count*count), 10.0/(count*count), 1.0);
    float ambientOcclusion = pow(count, 2.0) / 2000.0;
    gl_FragColor = vec4((gl_FragCoord.x / iResolution.x) - ambientOcclusion, (gl_FragCoord.y / iResolution.y) - ambientOcclusion, 1.0 - ambientOcclusion, 1.0);
}