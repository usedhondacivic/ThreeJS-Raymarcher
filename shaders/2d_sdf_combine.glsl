#define PI 3.1415926538

uniform float iTime;
uniform int iMode;
uniform vec2 iResolution;

float sdCircle( vec2 p, float r )
{
    return length(p) - r;
}

float sdBox( in vec2 p, in vec2 b )
{
    vec2 d = abs(p)-b;
    return length(max(d,0.0)) + min(max(d.x,d.y),0.0);
}

float sdBlobbyCross( in vec2 pos, float he )
{
    pos = abs(pos);
    pos = vec2(abs(pos.x-pos.y),1.0-pos.x-pos.y)/sqrt(2.0);

    float p = (he-pos.y-0.25/he)/(6.0*he);
    float q = pos.x/(he*he*16.0);
    float h = q*q - p*p*p;
    
    float x;
    if( h>0.0 ) { float r = sqrt(h); x = pow(q+r,1.0/3.0)-pow(abs(q-r),1.0/3.0)*sign(r-q); }
    else        { float r = sqrt(p); x = 2.0*r*cos(acos(q/(p*r))/3.0); }
    x = min(x,sqrt(2.0)/2.0);
    
    vec2 z = vec2(x,he*(1.0-2.0*x*x)) - pos;
    return length(z) * sign(z.y);
}

float dot2(vec2 d){
  return dot(d.xy, d.xy);
}

float sdHeart( in vec2 p )
{
    p.x = abs(p.x);

    if( p.y+p.x>1.0 )
        return sqrt(dot2(p-vec2(0.25,0.75))) - sqrt(2.0)/4.0;
    return sqrt(min(dot2(p-vec2(0.00,1.00)),
                    dot2(p-0.5*max(p.x+p.y,0.0)))) * sign(p.x-p.y);
}

float sdMoon(vec2 p, float d, float ra, float rb )
{
    p.y = abs(p.y);
    float a = (ra*ra - rb*rb + d*d)/(2.0*d);
    float b = sqrt(max(ra*ra-a*a,0.0));
    if( d*(p.x*b-p.y*a) > d*d*max(b-p.y,0.0) )
          return length(p-vec2(a,b));
    return max( (length(p          )-ra),
               -(length(p-vec2(d,0))-rb));
}

float sdHorseshoe( in vec2 p, in vec2 c, in float r, in float le, float th )
{
    p.x = abs(p.x);
    float l = length(p);
    p = mat2(-c.x, c.y, 
              c.y, c.x)*p;
    p = vec2((p.y>0.0 || p.x>0.0)?p.x:l*sign(-c.x),
             (p.x>0.0)?p.y:l );
    p = vec2(p.x-le,abs(p.y-r)-th);
    return length(max(p,0.0)) + min(0.0,max(p.x,p.y));
}

float ndot(vec2 a, vec2 b ) { return a.x*b.x - a.y*b.y; }
float sdRhombus( in vec2 p, in vec2 b ) 
{
    p = abs(p);
    float h = clamp( ndot(b-2.0*p,b)/dot(b,b), -1.0, 1.0 );
    float d = length( p-0.5*b*vec2(1.0-h,1.0+h) );
    return d * sign( p.x*b.y + p.y*b.x - b.x*b.y );
}

float getDist ( vec2 p){
  float circ = sdCircle(p - iResolution / 2.0 + vec2(0, 0), 85.0);
  float blobCross = sdBlobbyCross((p - iResolution / 2.0 + vec2(0, 0)) / 150.0 , 0.3) * 150.0;

  if(iMode == 0){
    return min(circ, blobCross);
  }else if(iMode == 1){
    return max(circ, -blobCross);
  }else{
    return max(circ, blobCross);
  }
}

void main()
{
	//vec3 viewDir = rayDirection(45.0, iResolution.xy, gl_FragCoord.xy);
  float background = 0.2;
  float dist = getDist(gl_FragCoord.xy);
  if(dist < 2.0 && dist > -2.0){
        gl_FragColor = vec4( 1.0, 1.0, 1.0 , 1.0);
        return;
  }
  float col = sign(dist);
  float change = 1.0;
  if(mod(dist, 14.0) > 7.0){
    change = 0.8;
  }
  if(dist > 0.0){
    float distAdj = exp(- dist / 200.0);
    gl_FragColor = vec4( 1.0 - col, 1.0 -  0.2 * col , 1.0 - 0.2 * col , 1.0 / (change * distAdj)) * change * distAdj;
  }else if(dist < 0.0){
    col *= -1.0;
    float distAdj = exp(dist / 100.0);
    gl_FragColor = vec4( 1.0 - 0.2 * col, 1.0 -  0.55 * col , 1.0 - col , 1.0 / (change * distAdj)) * change * distAdj;
  }
}