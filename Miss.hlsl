#include "Common.hlsl"

Texture2D skybox : register(t0);
SamplerState skyboxSampler : register(s0);

// Deprecated
[shader("miss")]
void Miss(inout HitInfo payload : SV_RayPayload)
{
	uint2 launchIndex = DispatchRaysIndex().xy;
	float2 dims = float2(DispatchRaysDimensions().xy);
	
    float3 rayDir = normalize(WorldRayDirection());
    float theta = acos(rayDir.y) / (PI);
    float phi = atan2(rayDir.x, rayDir.z) / (PI * 2.0f) + 0.5f;
    
    float3 col = skybox.SampleLevel(skyboxSampler, DirectionToSpherical(rayDir), 0).rgb;
    payload.colorAndDistance = float4(col, -1.0f);
}