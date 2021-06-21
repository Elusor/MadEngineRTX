#include "Common.hlsl"

Texture2D skybox : register(t0);
SamplerState skyboxSampler : register(s0);
//  Black hole generation shader

// Rotates a ray around a given axis
float3 BendRay(float3 rayDir, float3 rayOrigin, float3 holePosition, float angle)
{
    float3 originToHoleDir = normalize(holePosition - rayOrigin);
    float3 rotationAxis = normalize(cross(rayDir, originToHoleDir));
    float3 perpendicularAxis = normalize(cross(rotationAxis, rayDir));
    // Using simplified Rodrigues rotation formula where v and k are perpendicular
    float cosTh = cos(angle);
    float sinTh = sin(angle);
    
    float3 rotatedDir =
        rayDir * cosTh +
        perpendicularAxis * sinTh;
        // + (1.f - cosTh) * dot(rotationAxis, rayDir) * rotationAxis;
    
    return rotatedDir;
}

float CalculateB(float3 rayDir, float3 rayOrigin, float3 holePosition)
{
    float3 originToHole = holePosition - rayOrigin;
    float3 othRayDirComponent = dot(originToHole, rayDir) * rayDir;
    float3 bDirection = originToHole - othRayDirComponent;
    float b = length(bDirection);
    return b;
}

// Calculate the denominator of integrated function
float DenomFun(float w, float M, float b)
{
    float w2 = w * w;
    float w3 = w2 * w;    
    return w2 * ((2.0f * M / b) * w - 1) + 1.0f;
}

// Calculate the integrated function
float IntegrationFun(float w, float M, float b)
{
    float denominator = DenomFun(w, M, b);
    return pow(denominator, -0.5);
}

float FindRoot(float M, float b)
{   
    float eps = 0.000001f;
    
    int it = 0;
    int maxIt = 500;
    
    float l = 0;
    float r = b / (6 * M);
    float mid = (l + r) / 2.f;            
    
    while (abs(r - l) > eps && it < maxIt)
    {
        float lVal = DenomFun(l, M, b);
        float rVal = DenomFun(r, M, b);
        float midVal = DenomFun(mid, M, b);
        
        if (midVal == 0)
            return mid;
        
        if(lVal * midVal < 0)
        {
            //l = l;
            //lVal = lVal;
            r = mid;       
            rVal = midVal;            
        }
        else
        {
            l = mid;
            lVal = midVal;
            //r = r;                    
            //rVal = rVal;
        }
        
        mid = (l + r) / 2.f;
        midVal = DenomFun(mid, M, b);
        it++;
    }
       
    return l;
}

// Integrate bend angle derivative to determine total bend
float IntegrateBendAngle(float x0, float xn, float M, float b, float intervalCount)
{           
    // Simple numerical integration using trapezoidal rule
    float curKnot = x0;
    float sum = IntegrationFun(curKnot, M, b);
    
    float h = (xn - x0) / intervalCount;
    curKnot += h;
    
    for (int interval = 1; interval < intervalCount; interval++)
    {
        sum += 2.0f * IntegrationFun(curKnot, M, b);
        curKnot += h;
    }
    
    // Skipped due to integral not being defined at wMax
    // sum += IntegrationFun(xn, M, b);
    
    // Integration result
    sum *= (h / 2.0f);

    return sum;    
}


[shader("miss")]
void ReflectionMiss(inout ReflectionHitInfo hit : SV_RayPayload)
{   
    // TODO: adjust
    int integrationIntervalCount = 50;
    // TODO: Fix mass
    float M = 100;
       
    float3 rayDir = normalize(WorldRayDirection());    
    float3 rayOrigin = WorldRayOrigin();
    float3 blackHolePos = float3(0, 0, 0); 
     
    // 1. Calculate b factor
    float b = CalculateB(rayDir, rayOrigin, blackHolePos);    
    
    float3 texCol;
    if (b < sqrt(27.0f) * M) 
    {
        // Black hole light orbit
        texCol = float3(0.0f, 0.0f, 0.0f);        
    }
    else
    {
        float w0 = 0;
        float w1 = FindRoot(M, b);
        float bendAngle = 2.0f * IntegrateBendAngle(w0, w1, M, b, integrationIntervalCount) - PI;          
        float3 bentRay = BendRay(rayDir, rayOrigin, blackHolePos, bendAngle);
        texCol = skybox.SampleLevel(skyboxSampler, DirectionToSpherical(bentRay), 0).rgb;        
    }           
    
    hit.colorAndDistance = float4(texCol, -1.0f);
    hit.normalAndIsHit = float4(0.0f, 0.0f, 0.0f, 0.0f);
    hit.rayEnergy = float4(0.0f, 0.0f, 0.0f, 0.0f);
}