// This source code is port from shadertoy.com
// https://www.shadertoy.com/view/7t2XRm

#version 330
//============================================================================
// Constants.
//============================================================================

const float PI = 3.1415926536;

const vec3 BACKGROUND_COLOR = vec3( 0.1, 0.2, 0.6 );

// Vertical field-of-view angle of camera. In radians.
const float FOVY = 50.0 * PI / 180.0;

// Use this for avoiding the "epsilon problem" or the shadow acne problem.
const float DEFAULT_TMIN = 10.0e-4;

// Use this for tmax for non-shadow ray intersection test.
const float DEFAULT_TMAX = 10.0e6;

// Equivalent to number of recursion levels (0 means ray-casting only).
// We are using iterations to replace recursions.
const int NUM_ITERATIONS = 2;

// Constants for the scene objects.
const int NUM_LIGHTS = 2;
const int NUM_MATERIALS = 5;
const int NUM_PLANES = 1;
const int NUM_SPHERES = 3;
const int NUM_TRIANGLES = 20;

// Constant values for setting up
const float NEBULA_HEIGHT = 1.0;

//============================================================================
// Define new struct types.
//============================================================================
struct Ray_t {
    vec3 o;  // Ray Origin.
    vec3 d;  // Ray Direction. A unit vector.
};

struct Plane_t {
    // The plane equation is Ax + By + Cz + D = 0.
    float A, B, C, D;
    int materialID;
};

struct Sphere_t {
    vec3 center;
    float radius;
    int materialID;
};

struct Light_t {
    vec3 position;  // Point light 3D position.
    vec3 I_a;       // For Ambient.
    vec3 I_source;  // For Diffuse and Specular.
};

struct Triangle_t {
    vec3 p1;
    vec3 p2;
    vec3 p3;
    int materialID;
};

struct Material_t {
    vec3 k_a;   // Ambient coefficient.
    vec3 k_d;   // Diffuse coefficient.
    vec3 k_r;   // Reflected specular coefficient.
    vec3 k_rg;  // Global reflection coefficient.
    float n;    // The specular reflection exponent. Ranges from 0.0 to 128.0.
};

uniform float time;
uniform ivec2 iResolution;
uniform sampler2D iChannel0;

in vec2 uv;
out vec4 out_color;
//----------------------------------------------------------------------------
// The lighting model used here is similar to that on Slides 8 and 12 of
// Lecture Topic B08 (Basic Ray Tracing). Here it is computed as
//
//     I_local = SUM_OVER_ALL_LIGHTS {
//                   I_a * k_a +
//                   k_shadow * I_source * [ k_d * (N.L) + k_r * (R.V)^n ]
//               }
// and
//     I = I_local  +  k_rg * I_reflected
//----------------------------------------------------------------------------


//============================================================================
// Global scene data.
//============================================================================
Plane_t Plane[NUM_PLANES];
Sphere_t Sphere[NUM_SPHERES];
Light_t Light[NUM_LIGHTS];
Triangle_t Triangle[NUM_TRIANGLES];
Material_t Material[NUM_MATERIALS];



/////////////////////////////////////////////////////////////////////////////
// Initializes the scene.
/////////////////////////////////////////////////////////////////////////////
void InitScene()
{
    // Horizontal plane.
    Plane[0].A = 0.0;
    Plane[0].B = 1.0;
    Plane[0].C = 0.0;
    Plane[0].D = 0.0;
    Plane[0].materialID = 0;

    // Vertical plane.
    // Plane[1].A = 0.0;
    // Plane[1].B = 0.0;
    // Plane[1].C = 1.0;
    // Plane[1].D = 3.5;
    // Plane[1].materialID = 0;

    // Center bouncing sphere.
    // Sphere[0].center = vec3( 0.0, abs(sin(2.0 * time)) + 1.0, 0.0 );
    // Sphere[0].radius = 0.5;
    // Sphere[0].materialID = 1;

    // Circling sphere1.
    Sphere[0].center = vec3( 1.5 * cos(time), 0.5 + NEBULA_HEIGHT, 1.5 * sin(time) );
    Sphere[0].radius = 0.3;
    Sphere[0].materialID = 2;

    // Circling sphere2.
    Sphere[1].center = vec3( 1.5 * cos(time) + 0.6 * cos(1.5 * time + PI / 6.0), 
                             0.5 + NEBULA_HEIGHT + 0.2 * sin(time), 
                             1.5 * sin(time) + 0.6 * sin(1.5 * time + PI / 6.0) );
    Sphere[1].radius = 0.12;
    Sphere[1].materialID = 2;

    // Circling sphere3.
    Sphere[2].center = vec3( 2.8 * cos(2.5 * time), 
                             0.5 + NEBULA_HEIGHT + 0.5 * sin(2.5 * time), 
                             2.8 * sin(2.5 * time) );
    Sphere[2].radius = 0.2;
    Sphere[2].materialID = 3;

    // Cube Trianles.
    Triangle[0].p1 = vec3(-0.5, 1.0, -0.5);
    Triangle[0].p2 = vec3( 0.5, 0.0, -0.5);
    Triangle[0].p3 = vec3(-0.5, 0.0, -0.5);

    Triangle[1].p1 = vec3( 0.5, 1.0, -0.5);
    Triangle[1].p3 = vec3(-0.5, 1.0, -0.5);
    Triangle[1].p2 = vec3( 0.5, 0.0, -0.5);

    Triangle[2].p1 = vec3( 0.5, 1.0, -0.5);
    Triangle[2].p2 = vec3( 0.5, 0.0,  0.5);
    Triangle[2].p3 = vec3( 0.5, 0.0, -0.5);

    Triangle[3].p1 = vec3( 0.5, 1.0, -0.5);
    Triangle[3].p3 = vec3( 0.5, 0.0,  0.5);
    Triangle[3].p2 = vec3( 0.5, 1.0,  0.5);

    Triangle[4].p1 = vec3(-0.5, 1.0,  0.5);
    Triangle[4].p2 = vec3( 0.5, 0.0,  0.5);
    Triangle[4].p3 = vec3( 0.5, 1.0,  0.5);

    Triangle[5].p1 = vec3(-0.5, 1.0,  0.5);
    Triangle[5].p3 = vec3( 0.5, 0.0,  0.5);
    Triangle[5].p2 = vec3(-0.5, 0.0,  0.5);

    Triangle[6].p1 = vec3(-0.5, 0.0, -0.5);
    Triangle[6].p3 = vec3(-0.5, 1.0,  0.5);
    Triangle[6].p2 = vec3(-0.5, 0.0,  0.5);

    Triangle[7].p1 = vec3(-0.5, 0.0, -0.5);
    Triangle[7].p2 = vec3(-0.5, 1.0,  0.5);
    Triangle[7].p3 = vec3(-0.5, 1.0, -0.5);

    Triangle[8].p1 = vec3(-0.5, 0.0, -0.5);
    Triangle[8].p2 = vec3( 0.5, 0.0,  0.5);
    Triangle[8].p3 = vec3(-0.5, 0.0,  0.5);

    Triangle[9].p1 = vec3(-0.5, 0.0, -0.5);
    Triangle[9].p3 = vec3( 0.5, 0.0,  0.5);
    Triangle[9].p2 = vec3( 0.5, 0.0, -0.5);

    Triangle[10].p1 = vec3(-0.5, 1.0, -0.5);
    Triangle[10].p2 = vec3( 0.5, 1.0,  0.5);
    Triangle[10].p3 = vec3( 0.5, 1.0, -0.5);

    Triangle[11].p1 = vec3(-0.5, 1.0, -0.5);
    Triangle[11].p3 = vec3( 0.5, 1.0,  0.5);
    Triangle[11].p2 = vec3(-0.5, 1.0,  0.5);

    vec3 crystal[7] = vec3[]( vec3( 0.0, 1.7, 0.0 ),       // center
                              vec3( 0.0, 1.1, 0.0 ),       // bottom
                              vec3( 0.0, 2.3, 0.0 ),       // top
                              vec3( 0.3 * cos(time), 1.7, 0.3 * sin(time) ),
                              vec3(-0.3 * sin(time), 1.7, 0.3 * cos(time) ),
                              vec3( 0.3 * sin(time), 1.7,-0.3 * cos(time) ),
                              vec3(-0.3 * cos(time), 1.7,-0.3 * sin(time) ) );

    Triangle[12].p1 = crystal[1];
    Triangle[12].p2 = crystal[3];
    Triangle[12].p3 = crystal[4];

    Triangle[13].p1 = crystal[1];
    Triangle[13].p2 = crystal[3];
    Triangle[13].p3 = crystal[5];

    Triangle[14].p1 = crystal[1];
    Triangle[14].p2 = crystal[6];
    Triangle[14].p3 = crystal[4];

    Triangle[15].p1 = crystal[1];
    Triangle[15].p2 = crystal[6];
    Triangle[15].p3 = crystal[5];

    Triangle[16].p1 = crystal[2];
    Triangle[16].p2 = crystal[3];
    Triangle[16].p3 = crystal[4];

    Triangle[17].p1 = crystal[2];
    Triangle[17].p2 = crystal[3];
    Triangle[17].p3 = crystal[5];

    Triangle[18].p1 = crystal[2];
    Triangle[18].p2 = crystal[6];
    Triangle[18].p3 = crystal[4];

    Triangle[19].p1 = crystal[2];
    Triangle[19].p2 = crystal[6];
    Triangle[19].p3 = crystal[5];

    // Apply transformation to cube triangles
    for (int i = 0; i < 12; i++)
    {
        Triangle[i].p1.y *= 0.7 * abs(sin(time + PI / 2.0));
        Triangle[i].p2.y *= 0.7 * abs(sin(time + PI / 2.0));
        Triangle[i].p3.y *= 0.7 * abs(sin(time + PI / 2.0));
        Triangle[i].materialID = 1;
    }

    // Apply transformation to crystal triangles
    for (int i = 12; i < NUM_TRIANGLES; i++)
    {
        // Move up and down
        Triangle[i].p1.y += 0.5 * (sin(2.0 * time));
        Triangle[i].p2.y += 0.5 * (sin(2.0 * time));
        Triangle[i].p3.y += 0.5 * (sin(2.0 * time));
            
        // Material
        Triangle[i].materialID = 4;
    }

    // Silver material.
    Material[0].k_d = vec3( 0.5, 0.5, 0.5 );
    Material[0].k_a = 0.2 * Material[0].k_d;
    Material[0].k_r = 2.0 * Material[0].k_d;
    Material[0].k_rg = 0.5 * Material[0].k_r;
    Material[0].n = 64.0;

    // Gold material.
    Material[1].k_d = vec3( 0.8, 0.7, 0.1 );
    Material[1].k_a = 0.2 * Material[1].k_d;
    Material[1].k_r = 2.0 * Material[1].k_d;
    Material[1].k_rg = 0.5 * Material[1].k_r;
    Material[1].n = 64.0;

    // Green plastic material.
    Material[2].k_d = vec3( 0.0, 0.8, 0.0 );
    Material[2].k_a = 0.2 * Material[2].k_d;
    Material[2].k_r = vec3( 1.0, 1.0, 1.0 );
    Material[2].k_rg = 0.5 * Material[2].k_r;
    Material[2].n = 128.0;

    // Blue frosted material
    Material[3].k_d = vec3( 0.235, 0.364, 0.866 );
    Material[3].k_a = 0.2 * Material[2].k_d;
    Material[3].k_r = vec3( 1.0, 1.0, 1.0 );
    Material[3].k_rg = 0.5 * Material[2].k_r;
    Material[3].n = 32.0;

    // Rainbow material
    Material[4].k_d = vec3( abs(cos(time + PI / 6.0)), abs(sin(time + PI / 3.0)), abs(cos(time - PI / 2.0)) );
    Material[4].k_a = 0.1 * Material[2].k_d;
    Material[4].k_r = vec3( 1.0, 1.0, 1.0 );
    Material[4].k_rg = 0.6 * Material[2].k_r;
    Material[4].n = 64.0;

    // Light 0.
    Light[0].position = vec3( 4.0, 8.0, -3.0 );
    Light[0].I_a = vec3( 0.1, 0.1, 0.1 );
    Light[0].I_source = vec3( 0.85, 0.85, 0.85 );

    // Light 1.
    Light[1].position = vec3( -4.0, 10.0, 0.0 );
    Light[1].I_a = vec3( 0.1, 0.1, 0.1 );
    Light[1].I_source = vec3( 0.8, 0.8, 0.8 );
}



/////////////////////////////////////////////////////////////////////////////
// Computes intersection between a plane and a ray.
// Returns true if there is an intersection where the ray parameter t is
// between tmin and tmax, otherwise returns false.
// If there is such an intersection, outputs the value of t, the position
// of the intersection (hitPos) and the normal vector at the intersection
// (hitNormal).
/////////////////////////////////////////////////////////////////////////////
bool IntersectPlane( in Plane_t pln, in Ray_t ray, in float tmin, in float tmax,
                     out float t, out vec3 hitPos, out vec3 hitNormal )
{
    vec3 N = vec3( pln.A, pln.B, pln.C );
    float NRd = dot( N, ray.d );
    float NRo = dot( N, ray.o );
    float t0 = (-pln.D - NRo) / NRd;
    if ( t0 < tmin || t0 > tmax ) return false;

    // We have a hit -- output results.
    t = t0;
    hitPos = ray.o + t0 * ray.d;
    hitNormal = normalize( N );
    return true;
}



/////////////////////////////////////////////////////////////////////////////
// Computes intersection between a plane and a ray.
// Returns true if there is an intersection where the ray parameter t is
// between tmin and tmax, otherwise returns false.
/////////////////////////////////////////////////////////////////////////////
bool IntersectPlane( in Plane_t pln, in Ray_t ray, in float tmin, in float tmax )
{
    vec3 N = vec3( pln.A, pln.B, pln.C );
    float NRd = dot( N, ray.d );
    float NRo = dot( N, ray.o );
    float t0 = (-pln.D - NRo) / NRd;
    if ( t0 < tmin || t0 > tmax ) return false;
    return true;
}



/////////////////////////////////////////////////////////////////////////////
// Computes intersection between a sphere and a ray.
// Returns true if there is an intersection where the ray parameter t is
// between tmin and tmax, otherwise returns false.
// If there is one or two such intersections, outputs the value of the
// smaller t, the position of the intersection (hitPos) and the normal
// vector at the intersection (hitNormal).
/////////////////////////////////////////////////////////////////////////////
bool IntersectSphere( in Sphere_t sph, in Ray_t ray, in float tmin, in float tmax,
                      out float t, out vec3 hitPos, out vec3 hitNormal )
{
    /////////////////////////////////
    // TASK: WRITE YOUR CODE HERE. //
    /////////////////////////////////
    vec3 l_o = ray.o - sph.center;
    float a = dot(ray.d, ray.d);
    float b = 2.0 * dot(ray.d,  l_o);
    float c = dot(l_o, l_o) - sph.radius * sph.radius;
    float d = b * b - 4.0 * a *c;
    
    if (d < 0.0) return false;
    float t_m = (-b-sqrt(d)) / (2.0*a);
    float t_p = (-b+sqrt(d)) / (2.0*a);
    if ( (t_m >= tmin && t_m <= tmax) )
    {
        t = t_m;
        hitPos = ray.o + t * ray.d;
        hitNormal = normalize( l_o + t * ray.d );
        return true;
    }
    else if ( (t_p >= tmin &&  t_p <= tmax) )
    {
        t = t_p;
        hitPos = ray.o + t * ray.d;
        hitNormal = normalize( l_o + t * ray.d );
        return true;
    }
    return false;
}



/////////////////////////////////////////////////////////////////////////////
// Computes intersection between a sphere and a ray.
// Returns true if there is an intersection where the ray parameter t is
// between tmin and tmax, otherwise returns false.
/////////////////////////////////////////////////////////////////////////////
bool IntersectSphere( in Sphere_t sph, in Ray_t ray, in float tmin, in float tmax )
{
    /////////////////////////////////
    // TASK: WRITE YOUR CODE HERE. //
    /////////////////////////////////
    vec3 l_o = ray.o - sph.center;
    float a = dot(ray.d, ray.d);
    float b = 2.0 * dot(ray.d,  l_o);
    float c = dot(l_o, l_o) - sph.radius * sph.radius;
    float d = b * b - 4.0 * a *c;
    
    if (d < 0.0) return false;
    float t_m = (-b-sqrt(d)) / (2.0*a);
    float t_p = (-b+sqrt(d)) / (2.0*a);
    if ( (t_m >= tmin && t_m <= tmax) )
    {
        return true;
    }
    else if ( (t_p >= tmin &&  t_p <= tmax) )
    {
        return true;
    }
    return false;
}

bool IntersectTriangle( in Triangle_t tri, in Ray_t ray, in float tmin, in float tmax,
                      out float t, out vec3 hitPos, out vec3 hitNormal )
{
    mat3 cramer;
    mat3 A;
    A[0] = tri.p1 - tri.p2;
    A[1] = tri.p1 - tri.p3;
    A[2] = ray.d;
    float detA = determinant(A);

    cramer[0] = tri.p1 - ray.o;
    cramer[1] = tri.p1 - tri.p3;
    cramer[2] = ray.d;

    float beta = determinant(cramer) / detA;

    cramer[0] = tri.p1 - tri.p2;
    cramer[1] = tri.p1 - ray.o;
    cramer[2] = ray.d;

    float gamma = determinant(cramer) / detA;

    cramer[0] = tri.p1 - tri.p2;
    cramer[1] = tri.p1 - tri.p3;
    cramer[2] = tri.p1 - ray.o;

    float t0 = determinant(cramer) / detA;

    if (beta + gamma < 1.0 && beta > 0.0 && gamma > 0.0 && t0 > 0.0 && t0 > tmin && t0 < tmax) {
        t = t0;
        hitPos = ray.o + t * ray.d;
        hitNormal = normalize(cross(tri.p1 - tri.p2, tri.p1 - tri.p3));
        return true;
    }

    return false;

}

bool IntersectTriangle( in Triangle_t tri, in Ray_t ray, in float tmin, in float tmax )
{
    mat3 cramer;
    mat3 A;

    A[0] = tri.p1 - tri.p2;
    A[1] = tri.p1 - tri.p3;
    A[2] = ray.d;
    float detA = determinant(A);

    cramer[0] = tri.p1 - ray.o;
    cramer[1] = tri.p1 - tri.p3;
    cramer[2] = ray.d;

    float beta = determinant(cramer) / detA;

    cramer[0] = tri.p1 - tri.p2;
    cramer[1] = tri.p1 - ray.o;
    cramer[2] = ray.d;

    float gamma = determinant(cramer) / detA;

    cramer[0] = tri.p1 - tri.p2;
    cramer[1] = tri.p1 - tri.p3;
    cramer[2] = tri.p1 - ray.o;

    float t0 = determinant(cramer) / detA;

    if (beta + gamma < 1.0 && beta > 0.0 && gamma > 0.0 && t0 > 0.0 && t0 > tmin && t0 < tmax) {
        return true;
    }

    return false;
}



/////////////////////////////////////////////////////////////////////////////
// Computes (I_a * k_a) + k_shadow * I_source * [ k_d * (N.L) + k_r * (R.V)^n ].
// Input vectors L, N and V are pointing AWAY from surface point.
// Assume all vectors L, N and V are unit vectors.
/////////////////////////////////////////////////////////////////////////////
vec3 PhongLighting( in vec3 L, in vec3 N, in vec3 V, in bool inShadow,
                    in Material_t mat, in Light_t light )
{
    if ( inShadow ) {
        return light.I_a * mat.k_a;
    }
    else {
        vec3 R = reflect( -L, N );
        float N_dot_L = max( 0.0, dot( N, L ) );
        float R_dot_V = max( 0.0, dot( R, V ) );
        float R_dot_V_pow_n = ( R_dot_V == 0.0 )? 0.0 : pow( R_dot_V, mat.n );

        return light.I_a * mat.k_a +
               light.I_source * (mat.k_d * N_dot_L + mat.k_r * R_dot_V_pow_n);
    }
}

vec3 PhongLighting( in vec3 L, in vec3 N, in vec3 V, in bool inShadow,
                    in Material_t mat, in Light_t light, in vec2 uv )
{
    if ( inShadow ) {
        return light.I_a * mat.k_a;
    }
    else {
        vec3 R = reflect( -L, N );
        float N_dot_L = max( 0.0, dot( N, L ) );
        float R_dot_V = max( 0.0, dot( R, V ) );
        float R_dot_V_pow_n = ( R_dot_V == 0.0 )? 0.0 : pow( R_dot_V, mat.n );

        vec3 diffuse = vec3(0.0, 0.0, 0.0);//texture(iChannel0, uv).rgb;
        vec3 specular = diffuse;

        return light.I_a * mat.k_a +
               light.I_source * (diffuse * N_dot_L + specular * R_dot_V_pow_n);
    }
}



/////////////////////////////////////////////////////////////////////////////
// Casts a ray into the scene and returns color computed at the nearest
// intersection point. The color is the sum of light from all light sources,
// each computed using Phong Lighting Model, with consideration of
// whether the interesection point is being shadowed from the light.
// If there is no interesection, returns the background color, and outputs
// hasHit as false.
// If there is intersection, returns the computed color, and outputs
// hasHit as true, the 3D position of the intersection (hitPos), the
// normal vector at the intersection (hitNormal), and the k_rg value
// of the material of the intersected object.
/////////////////////////////////////////////////////////////////////////////
vec3 CastRay( in Ray_t ray,
              out bool hasHit, out vec3 hitPos, out vec3 hitNormal, out vec3 k_rg )
{
    // Find whether and where the ray hits some object.
    // Take the nearest hit point.

    bool hasHitSomething = false;
    float nearest_t = DEFAULT_TMAX;   // The ray parameter t at the nearest hit point.
    vec3 nearest_hitPos;              // 3D position of the nearest hit point.
    vec3 nearest_hitNormal;           // Normal vector at the nearest hit point.
    int nearest_hitMatID;             // MaterialID of the object at the nearest hit point.

    float temp_t;
    vec3 temp_hitPos;
    vec3 temp_hitNormal;
    bool temp_hasHit;

    /////////////////////////////////////////////////////////////////////////////
    // TASK:
    // * Try interesecting input ray with all the planes and spheres,
    //   and record the front-most (nearest) interesection.
    // * If there is interesection, need to record hasHitSomething,
    //   nearest_t, nearest_hitPos, nearest_hitNormal, nearest_hitMatID.
    /////////////////////////////////////////////////////////////////////////////

    /////////////////////////////////
    // TASK: WRITE YOUR CODE HERE. //
    /////////////////////////////////
    for ( int i = 0; i < NUM_PLANES; i++ )
    {
        temp_hasHit = IntersectPlane( Plane[i], ray, DEFAULT_TMIN, DEFAULT_TMAX,
                                        temp_t, temp_hitPos, temp_hitNormal );
        if ( temp_hasHit && temp_t < nearest_t )
        {
            nearest_t = temp_t;
            nearest_hitPos = temp_hitPos;
            nearest_hitNormal = temp_hitNormal;
            nearest_hitMatID = Plane[i].materialID;
        }
        if (!hasHitSomething && temp_hasHit) hasHitSomething = true;
    }
    
    for ( int i = 0; i < NUM_SPHERES; i++ )
    {
        temp_hasHit = IntersectSphere( Sphere[i], ray, DEFAULT_TMIN, DEFAULT_TMAX,
                                        temp_t, temp_hitPos, temp_hitNormal );
        if ( temp_hasHit && temp_t < nearest_t )
        {
            nearest_t = temp_t;
            nearest_hitPos = temp_hitPos;
            nearest_hitNormal = temp_hitNormal;
            nearest_hitMatID = Sphere[i].materialID;
        }
        if (!hasHitSomething && temp_hasHit) hasHitSomething = true;
    }

    for ( int i = 0; i < NUM_TRIANGLES; i++ )
    {
        temp_hasHit = IntersectTriangle( Triangle[i], ray, DEFAULT_TMIN, DEFAULT_TMAX,
                                        temp_t, temp_hitPos, temp_hitNormal );
        if ( temp_hasHit && temp_t < nearest_t )
        {
            nearest_t = temp_t;
            nearest_hitPos = temp_hitPos;
            nearest_hitNormal = temp_hitNormal;
            nearest_hitMatID = Triangle[i].materialID;
        }
        if (!hasHitSomething && temp_hasHit) hasHitSomething = true;
    }



    // One of the output results.
    hasHit = hasHitSomething;
    if ( !hasHitSomething ) return BACKGROUND_COLOR;

    vec3 I_local = vec3( 0.0 );  // Result color will be accumulated here.

    /////////////////////////////////////////////////////////////////////////////
    // TASK:
    // * Accumulate lighting from each light source on the nearest hit point.
    //   They are all accumulated into I_local.
    // * For each light source, make a shadow ray, and check if the shadow ray
    //   intersects any of the objects (the planes and spheres) between the
    //   nearest hit point and the light source.
    // * Then, call PhongLighting() to compute lighting for this light source.
    /////////////////////////////////////////////////////////////////////////////

    /////////////////////////////////
    // TASK: WRITE YOUR CODE HERE. //
    /////////////////////////////////
    for ( int i = 0; i < NUM_LIGHTS; i++ )
    {
        Ray_t shadowRay;
        shadowRay.o = nearest_hitPos;
        shadowRay.d = normalize(Light[i].position - nearest_hitPos);
        float shadowTMax = length(Light[i].position - nearest_hitPos);
        temp_hasHit = false;

        for ( int j = 0; j < NUM_PLANES; j++ )
        {
            if (temp_hasHit) break;
            temp_hasHit = IntersectPlane( Plane[j], shadowRay, DEFAULT_TMIN, shadowTMax );
        }
        
        for ( int j = 0; j < NUM_SPHERES; j++ )
        {
            if (temp_hasHit) break;
            temp_hasHit = IntersectSphere( Sphere[j], shadowRay, DEFAULT_TMIN, shadowTMax );
        }

        for ( int j = 0; j < NUM_TRIANGLES; j++ )
        {
            if (temp_hasHit) break;
            temp_hasHit = IntersectTriangle( Triangle[j], shadowRay, DEFAULT_TMIN, shadowTMax );
        }


        vec3 L = normalize(Light[i].position - nearest_hitPos);
        vec3 N = normalize(nearest_hitNormal);
        vec3 V = normalize(cross(L, N));
        I_local += PhongLighting(L, N, V, temp_hasHit, Material[nearest_hitMatID], Light[i]);
    }




    // Populate output results.
    hitPos = nearest_hitPos;
    hitNormal = nearest_hitNormal;
    k_rg = Material[nearest_hitMatID].k_rg;

    return I_local;
}



/////////////////////////////////////////////////////////////////////////////
// Execution of fragment shader starts here.
// 1. Initializes the scene.
// 2. Compute a primary ray for the current pixel (fragment).
// 3. Trace ray into the scene with NUM_ITERATIONS recursion levels.
/////////////////////////////////////////////////////////////////////////////
void main()
{
    InitScene();

    // Scale pixel 2D position such that its y coordinate is in [-1.0, 1.0].
    vec2 pixel_pos = (2.0 * uv.xy - iResolution.xy) / iResolution.y;

    // Position the camera.
    vec3 cam_pos = vec3( 4.5 * sin(0.3 * time), 3.0, 4.5 );
    vec3 cam_lookat = vec3( 0.25, 1.0, 0.0 );
    vec3 cam_up_vec = vec3( 0.0, 1.0, 0.0 );


    // Set up camera coordinate frame in world space.
    vec3 cam_z_axis = normalize( cam_pos - cam_lookat );
    vec3 cam_x_axis = normalize( cross(cam_up_vec, cam_z_axis) );
    vec3 cam_y_axis = normalize( cross(cam_z_axis, cam_x_axis));

    // Create primary ray.
    float pixel_pos_z = -1.0 / tan(FOVY / 2.0);
    Ray_t pRay;
    pRay.o = cam_pos;
    pRay.d = normalize( pixel_pos.x * cam_x_axis  +  pixel_pos.y * cam_y_axis  +  pixel_pos_z * cam_z_axis );


    // Start Ray Tracing.
    // Use iterations to emulate the recursion.

    vec3 I_result = vec3( 0.0 );
    vec3 compounded_k_rg = vec3( 1.0 );
    Ray_t nextRay = pRay;

    for ( int level = 0; level <= NUM_ITERATIONS; level++ )
    {
        bool hasHit;
        vec3 hitPos, hitNormal, k_rg;

        vec3 I_local = CastRay( nextRay, hasHit, hitPos, hitNormal, k_rg );

        I_result += compounded_k_rg * I_local;

        if ( !hasHit ) break;

        compounded_k_rg *= k_rg;

        nextRay = Ray_t( hitPos, normalize( reflect(nextRay.d, hitNormal) ) );
    }

    out_color = vec4( I_result, 1.0 );
}