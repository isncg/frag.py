#version 330 core
#define PI 3.14159265
#define RAYCAST_MAX 100000.0

in vec2 screenCoord;

uniform sampler2D diffuseMap;
uniform sampler2D specularMap;
uniform sampler2D envMap;
uniform vec2 screenSize;

out vec4 FragColor;

//////////////////////////////////////////////////////////////////////////////
uint wseed;
uint whash(uint seed)
{
    seed = (seed ^ uint(61)) ^ (seed >> uint(16));
    seed *= uint(9);
    seed = seed ^ (seed >> uint(4));
    seed *= uint(0x27d4eb2d);
    seed = seed ^ (seed >> uint(15));
    return seed;
}

float randcore4()
{
	wseed = whash(wseed);

	return float(wseed) * (1.0 / 4294967296.0);
}

void seedcore3(vec2 screenCoord)
{
	wseed = uint(screenCoord.x * screenSize.x + screenCoord.y * screenSize.x * screenSize.y);
}

void seed(vec2 screenCoord)
{
	seedcore3(screenCoord);
}

float rand()
{
	return randcore4();
}

vec2 rand2()
{
	return vec2(rand(), rand());
}

vec3 rand3()
{
	return vec3(rand(), rand(), rand());
}

vec4 rand4()
{
	return vec4(rand(), rand(), rand(), rand());
}

vec3 random_in_unit_sphere()
{
	// vec3 p;
	// 
	// do
	// {
	// 	p = 2.0 * rand3() - vec3(1, 1, 1);
	// }while(dot(p, p)>=1.0);
	// return p;

	vec3 p;
	
	float theta = rand() * 2.0 * PI;
	float phi   = rand() * PI;
	p.y = cos(phi);
	p.x = sin(phi) * cos(theta);
	p.z = sin(phi) * sin(theta);
	
	return p;
}

///////////////////////////////////////////////////////////////////////////////
struct Ray {
    vec3 origin;
    vec3 direction;
}; 

struct Camera 
{
    vec3 lower_left_corner;
    vec3 horizontal;
	vec3 vertical;
	vec3 origin;
}; 

struct LambertianMaterial
{
	vec3 albedo;
};

struct MetallicMaterial
{
	vec3 albedo;
};

struct Sphere 
{
    vec3 center;
    float radius;
	int materialType;
	int material;
}; 

struct HitRecord
{
	float t;
	vec3 position;
	vec3 normal;
	
	int materialType;
	int material;
};

struct World
{
	int objectCount;
	Sphere objects[10];
};


//////////////////////////////////////////////-//////////////////////////////////////
Ray RayConstructor(vec3 origin, vec3 direction)
{
	Ray ray;
	ray.origin = origin;
	ray.direction = direction;

	return ray;
}

vec3 RayGetPointAt(Ray ray, float t)
{
	return ray.origin + t * ray.direction;
}

////////////////////////////////////////////////////////////////////////////////////
Camera CameraConstructor(vec3 lower_left_corner, vec3 horizontal, vec3 vertical, vec3 origin)
{
	Camera camera;

	camera.lower_left_corner = lower_left_corner;
	camera.horizontal = horizontal;
	camera.vertical = vertical;
	camera.origin = origin;

	return camera;
}

Ray CameraGetRay(Camera camera, vec2 uv)
{
	Ray ray = RayConstructor(camera.origin, 
		camera.lower_left_corner + 
		uv.x * camera.horizontal + 
		uv.y * camera.vertical);

	return ray;
}

////////////////////////////////////////////////////////////////////////////////////
#define MAT_LAMBERTIAN		0
#define MAT_METALLIC	1
#define MAT_DIELECTRIC	2
#define MAT_PBR			3

struct Lambertian
{
	vec3 albedo;
};

Lambertian LambertianConstructor(vec3 albedo)
{
	Lambertian lambertian;

	lambertian.albedo = albedo;

	return lambertian;
}

bool LambertianScatter(in Lambertian lambertian, in Ray incident, in HitRecord hitRecord, out Ray scattered, out vec3 attenuation)
{
	attenuation = lambertian.albedo;

	scattered.origin = hitRecord.position;
	scattered.direction = hitRecord.normal + random_in_unit_sphere();

	return true;
}

struct Metallic
{
	vec3 albedo;
	float roughness;
};

Metallic MetallicConstructor(vec3 albedo, float roughness)
{
	Metallic metallic;

	metallic.albedo = albedo;
	metallic.roughness = roughness;

	return metallic;
}

float schlick(float cosine, float ior)
{
	float r0 = (1 - ior) / (1 + ior);
	r0 = r0 * r0;
	return r0 + (1 - r0) * pow((1 - cosine), 5);
}

vec3 reflect(in vec3 incident, in vec3 normal)
{
	return incident - 2 * dot(normal, incident) * normal;
}

bool refract(vec3 v, vec3 n, float ni_over_nt, out vec3 refracted)
{
	vec3 uv = normalize(v);
	float dt = dot(uv, n);
	float discriminant = 1.0 - ni_over_nt * ni_over_nt * (1.0 - dt * dt);
	if (discriminant > 0)
	{
		refracted = ni_over_nt * (uv - n * dt) - n * sqrt(discriminant);
		return true;
	}
	else
		return false;
}

bool MetallicScatter(in Metallic metallic, in Ray incident, in HitRecord hitRecord, out Ray scattered, out vec3 attenuation)
{
	attenuation = metallic.albedo;

	scattered.origin = hitRecord.position;
	scattered.direction = reflect(incident.direction, hitRecord.normal);

	return dot(scattered.direction, hitRecord.normal) > 0.0;
}

struct Dielectric
{
	vec3 albedo;
	float roughness;
	float ior;
};

Dielectric DielectricConstructor(vec3 albedo, float roughness, float ior)
{
	Dielectric dielectric;

	dielectric.albedo = albedo;
	dielectric.roughness = roughness;
	dielectric.ior = ior;

	return dielectric;
}

bool DielectricScatter1(in Dielectric dielectric, in Ray incident, in HitRecord hitRecord, out Ray scattered, out vec3 attenuation)
{
	attenuation = dielectric.albedo;
	vec3 reflected = reflect(incident.direction, hitRecord.normal);

	vec3 outward_normal;
	float ni_over_nt;
	if(dot(incident.direction, hitRecord.normal) > 0.0)// hit from inside
	{
		outward_normal = -hitRecord.normal;
		ni_over_nt = dielectric.ior;
	}
	else // hit from outside
	{
		outward_normal = hitRecord.normal;
		ni_over_nt = 1.0 / dielectric.ior;
	}

	vec3 refracted;
	if(refract(incident.direction, outward_normal, ni_over_nt, refracted))
	{
		scattered = Ray(hitRecord.position, refracted);

		return true;
	}
	else
	{
		scattered = Ray(hitRecord.position, reflected);

		return false;
	}
}

bool DielectricScatter2(in Dielectric dielectric, in Ray incident, in HitRecord hitRecord, out Ray scattered, out vec3 attenuation)
{
	attenuation = dielectric.albedo;
	vec3 reflected = reflect(incident.direction, hitRecord.normal);

	vec3 outward_normal;
	float ni_over_nt;
	float cosine;
	if(dot(incident.direction, hitRecord.normal) > 0.0)// hit from inside
	{
		outward_normal = -hitRecord.normal;
		ni_over_nt = dielectric.ior;
		cosine = dot(incident.direction, hitRecord.normal) / length(incident.direction); // incident angle
	}
	else // hit from outside
	{
		outward_normal = hitRecord.normal;
		ni_over_nt = 1.0 / dielectric.ior;
		cosine = -dot(incident.direction, hitRecord.normal) / length(incident.direction); // incident angle
	}

	float reflect_prob;
	vec3 refracted;
	if(refract(incident.direction, outward_normal, ni_over_nt, refracted))
	{
		reflect_prob = schlick(cosine, dielectric.ior);
	}
	else
	{
		reflect_prob = 1.0;
	}

	if(rand() < reflect_prob)
	{
		scattered = Ray(hitRecord.position, refracted);
	}
	else
	{
		scattered = Ray(hitRecord.position, refracted);
	}

	return true;
}

bool DielectricScatter(in Dielectric dielectric, in Ray incident, in HitRecord hitRecord, out Ray scattered, out vec3 attenuation)
{
	//return DielectricScatter1(dielectric, incident, hitRecord, scattered, attenuation);
	return DielectricScatter2(dielectric, incident, hitRecord, scattered, attenuation);
}

////////////////////////////////////////////////////////////////////////////////////
Sphere SphereConstructor(vec3 center, float radius, int materialType, int material)
{
	Sphere sphere;

	sphere.center = center;
	sphere.radius = radius;
	sphere.materialType = materialType;
	sphere.material = material;

	return sphere;
}

////////////////////////////////////////////////////////////////////////////////////
bool SphereHit(Sphere sphere, Ray ray, float t_min, float t_max, inout HitRecord hitRecord)
{
	vec3 oc = ray.origin - sphere.center;
	
	float a = dot(ray.direction, ray.direction);
	float b = dot(oc, ray.direction);
	float c = dot(oc, oc) - sphere.radius * sphere.radius;

	float discriminant = b * b - a * c;
	if(discriminant>0)
	{
		float temp = (-b - sqrt(discriminant)) / a;
		if(temp < t_max && temp> t_min)
		{
			hitRecord.t = temp;
			hitRecord.position = RayGetPointAt(ray, hitRecord.t);
			hitRecord.normal = (hitRecord.position - sphere.center) / sphere.radius;
			
			hitRecord.materialType = sphere.materialType;
			hitRecord.material = sphere.material;
			return true;
		}

		temp = (-b + sqrt(discriminant)) / a;
		if(temp < t_max && temp> t_min)
		{
			hitRecord.t = temp;
			hitRecord.position = RayGetPointAt(ray, hitRecord.t);
			hitRecord.normal = (hitRecord.position - sphere.center) / sphere.radius;

			hitRecord.materialType = sphere.materialType;
			hitRecord.material = sphere.material;
			
			return true;
		}
	}
	
	return false;
}

// ////////////////////////////////////////////////////////////////////////////////////
// World WorldConstructor()
// {
// 	World world;

// 	world.objectCount = 4;
// 	world.objects[0] = SphereConstructor(vec3( 0.0,    0.0, -1.0), 0.25, MAT_LAMBERTIAN, 0);
// 	world.objects[1] = SphereConstructor(vec3( 0.7,    0.0, -1.0), 0.25, MAT_METALLIC, 1);
// 	world.objects[2] = SphereConstructor(vec3(-0.7,    0.0, -1.0), 0.25, MAT_DIELECTRIC, 2);
// 	world.objects[3] = SphereConstructor(vec3( 0.0, -100.5, -1.0), 100.0, MAT_LAMBERTIAN, 3);

// 	return world;
// }

bool WorldHit(World world, Ray ray, float t_min, float t_max, inout HitRecord rec)
{
	float cloestSoFar = t_max;
	bool hitSomething = false;
	HitRecord tempRec;

	for(int i=0; i<world.objectCount; i++)
	{
		if(SphereHit(world.objects[i], ray, t_min, cloestSoFar, tempRec))
		{
			hitSomething = true;
			cloestSoFar = tempRec.t;
			
			rec = tempRec;
		}
	}

	return hitSomething;
}

/////////////////////////////////////////////////////////////////////////////////
uniform World world;
uniform Camera camera;
uniform Lambertian lambertMaterials[4];
uniform Metallic metallicMaterials[4];
uniform Dielectric dielectricMaterials[4];

bool MaterialScatter(in int materialType, in int material, in Ray incident, in HitRecord hitRecord, out Ray scatter, out vec3 attenuation)
{
	if(materialType==MAT_LAMBERTIAN)
		return LambertianScatter(lambertMaterials[material], incident, hitRecord, scatter, attenuation);
	else if(materialType==MAT_METALLIC)
		return MetallicScatter(metallicMaterials[material], incident, hitRecord, scatter, attenuation);
	else if(materialType==MAT_DIELECTRIC)
		return DielectricScatter(dielectricMaterials[material], incident, hitRecord, scatter, attenuation);
	else
		return false;
}

vec3 GetBGColor(World world, Ray ray)
{
	vec3 unit_direction = normalize(ray.direction);
	float t = 0.5 * (unit_direction.y + 1.0);
	return vec3(1.0, 1.0, 1.0) * (1.0 - t) + vec3(0.4, 0.56, 1.0) * t;

	// vec3 dir = normalize(ray.direction);
	// float theta = acos(dir.y) / PI;
	// float phi = (atan(dir.x, dir.z) / (PI) + 1.0) / 2.0;
	// return texture(envMap, vec2(phi, theta)).xyz;
}

/*
vec3 WorldTrace(World world, Ray ray)
{
	HitRecord hitRecord;
	if(WorldHit(world, ray, 0.001, RAYCAST_MAX, hitRecord))
	{
		ray = RayConstructor(hitRecord.position, hitRecord.normal + random_in_unit_sphere());
		WorldTrace(world, ray);
	}
	else
	{
		return GetBGColorColor(world, ray);
	}
}
*/

vec3 WorldTrace(World world, Ray ray, int depth)
{
	HitRecord hitRecord;

	vec3 frac = vec3(1.0, 1.0, 1.0);
	vec3 bgColor = vec3(0.0, 0.0, 0.0);
	while(depth>0)
	{
		depth--;
		if(WorldHit(world, ray, 0.001, RAYCAST_MAX, hitRecord))
		{
			Ray scatterRay;
			vec3 attenuation;
			if(!MaterialScatter(hitRecord.materialType, hitRecord.material, ray, hitRecord, scatterRay, attenuation))
				break;
			
			frac *= attenuation;
			ray = scatterRay;
		}
		else
		{
			bgColor = GetBGColor(world, ray);
			break;
		}
	}

	return bgColor * frac;
}

vec3 GammaCorrection(vec3 c)
{
	return pow(c, vec3(1.0 / 2.2));
}

vec3 InverseGammaCorrection(vec3 c)
{
	return pow(c, vec3(2.2));
}

uniform int ns;
void main()
{
	seed(screenCoord);
	vec3 col = vec3(0.0, 0.0, 0.0);
	//int ns = 100;
	for(int i=0; i<ns; i++)
	{
		Ray ray = CameraGetRay(camera, screenCoord + rand2() / screenSize);
		col += WorldTrace(world, ray, 50);
	}
	col /= ns;

	//col = GammaCorrection(col);

	FragColor.xyz = col;
	FragColor.w = 1.0;
}