#include "Common.hlsl"

Texture2D skybox : register(t0);
SamplerState skyboxSampler : register(s0);
//  Black hole generation shader

float CalculateUpperIntegrationLimit(float M, float b)
{
    float b2 = b * b;
    float b3 = b2 * b;
    float b4 = b3 * b;
    float M2 = M * M;
    float M4 = M2 * M2;
    
    float weirdRoot = pow(-b3 + 54.0f * b * M2 + 6.0f * b * M * sqrt(-3.0f * b2 + 81.0f * M2), 1.0f / 3.0f);
    
    float eps = 0.0f;
    return (-b + (b2 / weirdRoot) + weirdRoot) / (6.0f * M) - eps;
}

// Calculate the integrated function
float CalculatePhiDerivativeValue(float w, float M, float b)
{
    float mbFactor = 2.0f * M / b;
    float denominator = (1.0f - w * w * (1 - w * mbFactor));
    float sqrtDenom = sqrt(denominator);
    return (1.0f / sqrtDenom);
}

float CalculateB(float3 rayDir, float3 rayOrigin, float3 holePosition)
{
    float3 originToHole = holePosition - rayOrigin;    
    float3 othRayDirComponent = dot(originToHole, rayDir) * rayDir;
    float3 bDirection = originToHole - othRayDirComponent;
    float b = length(bDirection);    
    return b;
}

// Integrate bend angle derivative to determine total bend
float CalculateRayBendAngle(float w0, float wMax, float M, float b, float intervalCount)
{
    // Simple numerical integration using trapezoidal rule
    float curKnot = w0;
    float totalFunctionValue = CalculatePhiDerivativeValue(curKnot, M, b);    
    
    float knotIncrement = (wMax - w0) / intervalCount;
    curKnot += knotIncrement;
    
    for (int interval = 1; interval < intervalCount; interval++)
    {
        totalFunctionValue += 2.0f * CalculatePhiDerivativeValue(curKnot, M, b);
        curKnot += knotIncrement;
    }
    
    // Skipped due to integral not being defined at wMax
    totalFunctionValue += CalculatePhiDerivativeValue(wMax, M, b);
    
    // Integration result
    totalFunctionValue *= (knotIncrement / 2.0f);
    
    // Formula adjustment deltaPhi = 2 * integral
    float endValue = 2.0f * totalFunctionValue - PI;
    return endValue;
}

// Rotates a ray around a given axis
float3 BendRay(float3 rayDir, float3 rayOrigin, float3 holePosition, float angle)
{       
    float3 originToHoleDir = normalize(holePosition - rayOrigin);
    float3 rotationAxis = cross(rayDir, originToHoleDir);
   
    // Using Rodrigues rotation formula
    float cosTh = cos(angle);
    float rotatedDir = 
        rayDir * cosTh +
        cross(rotationAxis, rayDir) * sin(angle) + 
        (1.f - cosTh) * dot(rotationAxis, rayDir) * rotationAxis;
        
    return rotatedDir;
}

[shader("miss")]
void ReflectionMiss(inout ReflectionHitInfo hit : SV_RayPayload)
{   
    int integrationIntervalCount = 1000; 
    float M = 5; // 600 solar masses
        
    float3 rayDir = normalize(WorldRayDirection());    
    float3 rayOrigin = WorldRayOrigin();
    float3 blackHolePos = float3(0, 0, 0);
     
    // 1. Calculate b factor
    float b = CalculateB(rayDir, rayOrigin, blackHolePos);    
    float w0 = 0;
    float w1 = CalculateUpperIntegrationLimit(M, b);
    
    // 2. Calculate bend angle based on current parameters        
    float bendAngle = CalculateRayBendAngle(w0, w1, M, b, integrationIntervalCount);    
    // 3a. If Bend is not finite - return black


    // 3b. If bend is finite - bend ray           
    float3 bentRay = BendRay(rayDir, rayOrigin, blackHolePos, -bendAngle);
    
    float3 texCol;
    if ((bendAngle) < PI)
    {
        texCol = float3(0.0f, 0.0f, 1.0f);
    }
    
    
    if ((bendAngle) < PI / 2)
    {
        texCol = float3(0.0f, 1.0f, 0.0f);
    }
    
    if ((bendAngle) < 0)
    {
        texCol = float3(1.0f, 0.0f, 0.0f);
    }
    
    //if ((bendAngle) > PI)
    //{
    //    texCol = float3(1.0f, 1.0f, 0.0f);
    //}
    
    else
    {
        texCol = skybox.SampleLevel(skyboxSampler, DirectionToSpherical(rayDir), 0).rgb;
    }
    
    float3 col;
    
    bool debugRender = false;    
    if(debugRender)
    {                
        float3 debugCol = float3(b, 0, 0);
        col = lerp(texCol, debugCol, 1);
    }
    else
    {
        col = texCol;
    }    
    
    hit.colorAndDistance = float4(col, -1.0f);
    hit.normalAndIsHit = float4(0.0f, 0.0f, 0.0f, 0.0f);
    hit.rayEnergy = float4(0.0f, 0.0f, 0.0f, 0.0f);
}