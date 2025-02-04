#include "Common.hlsl"


// #DXR Extra: Per-Instance Data (Global Constant Buffer, Layout 2)
struct MyStructColor
{
    float4 a;
    float4 b;
    float4 c;
};

cbuffer Colors : register(b0)
{
    // #DXR Extra: Per-Instance Data (Global Constant Buffer, Layout 1)
    //float4 A[3];
    //float4 B[3];
    //float4 C[3];
    
    // #DXR Extra: Per-Instance Data (Global Constant Buffer, Layout 2)
    //MyStructColor Tint[3];
    
    // #DXR Extra: Per-Instance Data (Per-Instance Constant Buffer)
    Material mat;
}


StructuredBuffer<STriVertex> BTriVertex : register(t0);
StructuredBuffer<int> indices : register(t1);

// #DXR Extra: Another Ray Type
// Raytracing acceleration structure, accessed as a SRV
RaytracingAccelerationStructure SceneBVH : register(t2);


//LEGACY SHADER - no longer used by main RayGen shader
[shader("closesthit")] 
void ClosestHit(inout HitInfo payload, Attributes attrib) 
{
	float3 barycentrics =
		float3(1.0f - attrib.bary.x - attrib.bary.y, attrib.bary.x, attrib.bary.y);

	uint vertId = 3 * PrimitiveIndex();
    
    // #DXR Custom: Directional Shadows for tetrahedron
    float3x4 objectToWorld = ObjectToWorld();
    float3 v1 = mul(objectToWorld, BTriVertex[indices[vertId + 0]].vertex);
    float3 v2 = mul(objectToWorld, BTriVertex[indices[vertId + 1]].vertex);
    float3 v3 = mul(objectToWorld, BTriVertex[indices[vertId + 2]].vertex);
    
    float minTMult = length(v2 - v3);
    
    // #DXR Custom: Directional Shadows for tetrahedron
    float3 normal = normalize(cross((v2 - v3), (v1 - v2)));
    if (dot(normal, WorldRayDirection()) > 0.0f)
    {
        normal = -normal;
    }
    
    // #DXR Custom: Directional Shadows for tetrahedron
    //float3 lightPos = float3(2.0f, 2.0f, -2.0f);
    float3 worldOrigin = WorldRayOrigin() + RayTCurrent() * WorldRayDirection();
    
    float3 vectToLight = LIGHT_POS - worldOrigin;
    float3 distToLight = length(vectToLight);
    float3 lightDir = normalize(vectToLight);
    
    // #DXR Custom: Directional Shadows
    //bool isLightValid = dot(normal, lightDir) > 0.0f;
    
    // #DXR Custom: Simple Lighting
    float diff = max(dot(normal, lightDir), 0.0f);
    float3 diffuse = diff * LIGHT_COL;
    
    RayDesc ray;
    ray.Origin = worldOrigin;
    ray.Direction = lightDir;
    ray.TMin = clamp(MIN_SECONDARY_RAY_T * minTMult, MIN_SECONDARY_RAY_T, MIN_SECONDARY_RAY_T_MAX_VALUE);
    ray.TMax = distToLight;
    bool hit = true;
    
    // Initialize the ray payload
    ShadowHitInfo shadowPayload;
    shadowPayload.isHit = false;
    
    // Trace the ray
    TraceRay(
    // Acceleration structure
    SceneBVH,
    // Flags can be used to specify the behavior upon hitting a surface
    DEFAULT_RAY_FLAG,
    // Instance inclusion mask
    0xFF,
    // Depending on the type of ray, a given object can have several hit
    // groups attached (ie. what to do when hitting to compute regular
    // shading, and what to do when hitting to compute shadows). Those hit
    // groups are specified sequentially in the SBT, so the value below
    // indicates which offset (on 4 bits) to apply to the hit groups for this
    // ray. In this sample we now have two hit groups per object, where second
    // hit group is for shadow rays, hence an offset of 1.
    1,
    // The offsets in the SBT can be computed from the object ID, its instance
    // ID, but also simply by the order the objects have been pushed in the
    // acceleration structure. This allows the application to group shaders in
    // the SBT in the same order as they are added in the AS, in which case
    // the value below represents the stride (4 bits representing the number
    // of hit groups) between two consecutive objects.
    0,
    // Index of the miss shader: shadow miss shader
    1,
    // Ray information to trace
    ray,
    // Payload associated to the ray, which will be used to communicate
    // between the hit/miss shaders and the raygen
    shadowPayload);
    
    
    float3 currentRayEnergy = float3(1.0f, 1.0f, 1.0f);
    float3 resultColor = float3(0.0f, 0.0f, 0.0f);
    float3 currentPosition = worldOrigin;
    float3 currentDirection = WorldRayDirection();
    float3 currentNormal = normal;
    float currentMinTMult = minTMult;
    
    resultColor += currentRayEnergy * (0.0f, 0.0f, 0.0f);
    currentRayEnergy *= mat.specular;
    
    ReflectionHitInfo reflectionPayload;
    int lastValidReflection = 0;
    int i;
    for (i = 0; i < NUM_REFLECTIONS; i++)
    {
        currentDirection = reflect(currentDirection, currentNormal);
        // Fire a reflection ray.
        ray.Origin = currentPosition;
        ray.Direction = currentDirection;
        ray.TMin = clamp(MIN_SECONDARY_RAY_T * currentMinTMult, MIN_SECONDARY_RAY_T, MIN_SECONDARY_RAY_T_MAX_VALUE);
        ray.TMax = MAX_RAY_T;
    
        // Initialize the ray payload
        reflectionPayload.colorAndDistance = float4(0.0f, 0.0f, 0.0f, 0.0f);
        reflectionPayload.normalAndIsHit = float4(0.0f, 0.0f, 0.0f, 0.0f);
        reflectionPayload.rayEnergy = float4(currentRayEnergy, 1.0f);
    
        // Trace the ray
        TraceRay(
            SceneBVH, // Acceleration structure
            DEFAULT_RAY_FLAG, // Flags 
            0xFF, // Instance inclusion mask: include all
            2, // Hit group offset : reflection hit group
            0, // SBT offset
            2, // Index of the miss shader: reflection miss shader
            ray, // Ray information to trace
            reflectionPayload); // Payload
        
        resultColor += currentRayEnergy * reflectionPayload.colorAndDistance.rgb;
        currentRayEnergy = reflectionPayload.rayEnergy.rgb;
        
        lastValidReflection = i;
        if (reflectionPayload.normalAndIsHit.w == 0.0f)
        {
            break;
        }
        else
        {
            currentMinTMult = reflectionPayload.normalAndIsHit.w;
        }
        
        currentPosition += currentDirection * reflectionPayload.colorAndDistance.w;
        currentNormal = reflectionPayload.normalAndIsHit.xyz;
        
    }
    
    // #DXR Custom: Directional Shadows
    //float factor = shadowPayload.isHit || !isLightValid ? 0.3f : 1.0f;
    
    // #DXR Custom: Simple Lighting
    float diffFactor = shadowPayload.isHit ? 0.0f : 1.0f;
    
    //float3 hitColor = BTriVertex[vertId + 0].color * barycentrics.x +
	//				    BTriVertex[vertId + 1].color * barycentrics.y +
	//				    BTriVertex[vertId + 2].color * barycentrics.z;
	
    //float3 A = float3(1.0f, 0.0f, 0.0f);
    //float3 B = float3(0.0f, 1.0f, 0.0f);
    //float3 C = float3(0.0f, 0.0f, 1.0f);
    
	// #DXR Extra: Per-Instance Data
    //float3 hitColor = float3(0.7f, 0.7f, 0.7f);

    // #DXR Extra: Per-Instance Data (Global Constant Buffer, Layout 2)
    //if (InstanceID() < 3)
    //{
    //    hitColor = Tint[InstanceID()].a * barycentrics.x + Tint[InstanceID()].b * barycentrics.y + Tint[InstanceID()].c * barycentrics.z;
    //}
    
    // #DXR Extra: Per-Instance Data (Per-Instance Constant Buffer)
    // hitColor = A * barycentrics.x + B * barycentrics.y + C * barycentrics.z;
    
    // #DXR Extra: Indexed Geometry
    float3 objectColor = BTriVertex[indices[vertId + 0]].color * barycentrics.x +
                         BTriVertex[indices[vertId + 1]].color * barycentrics.y +
                         BTriVertex[indices[vertId + 2]].color * barycentrics.z;
    
    // #DXR Custom: Simple Lighting
    float3 hitColor = (diffFactor * diffuse + AMBIENT_FACTOR * LIGHT_COL) * objectColor;
    //float3 reflColor = /*MIX_FACTOR * */reflectionPayloads[lastValidReflection].colorAndDistance.xyz /*+ (1.0f - MIX_FACTOR) * SKY_COL*/;
    
    //for (i = lastValidReflection - 1; i >= 0; i--)
    //{
    //    reflColor = MIX_FACTOR * reflectionPayloads[i].colorAndDistance.xyz + (1.0f - MIX_FACTOR) * reflColor;
    //}
    
    //hitColor = MIX_FACTOR * hitColor + (1.0f - MIX_FACTOR) * reflColor;
	payload.colorAndDistance = float4(resultColor, RayTCurrent());
}