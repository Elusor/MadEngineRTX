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
        // dot is always 0 here
        // + (1.f - cosTh) * dot(rotationAxis, rayDir) * rotationAxis;
    
    return rotatedDir;
}

// Calculate distance from ray to the black hole
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

// Calculate the integrated function (dPhi/dr) 
float IntegrationFun(float w, float M, float b)
{
    float denominator = DenomFun(w, M, b);
    return pow(denominator, -0.5);
}

// Find root using bisection method
bool FindRoot(float M, float b, inout float w1)
{   
    float eps = 1e-8f;
    
    int it = 0;
    int maxIt = 500;
    
    // Optimal left and right start values derived from DenomFun Maxima/Minima
    float l = 0;
    float r = b / (3 * M);
    float mid = (l + r) / 2.f;     
    
    float lVal = DenomFun(l, M, b);
    float rVal = DenomFun(r, M, b);
        
    if (lVal * rVal > 0)
    {
        w1 = 0.0f;
        return false;
    }
    
    while (abs(r - l) > eps && it < maxIt)
    {
        lVal = DenomFun(l, M, b);
        rVal = DenomFun(r, M, b);
        float midVal = DenomFun(mid, M, b);
                        
        if (midVal == 0)
            return mid;
        
        if (lVal * midVal < 0)
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
        
    w1 = l;
    return true;
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
    
    // Offset Wmax to prevent from division by 0
    float lastOffset = -h / 10.f;
    sum += IntegrationFun(xn + lastOffset, M, b);
    
    // Integration result
    sum *= (h / 2.0f);

    return sum;    
} 

[shader("miss")]
void ReflectionMiss(inout ReflectionHitInfo hit : SV_RayPayload)
{       
    int integrationIntervalCount = 250;
    float M = 100000000;
       
    float3 rayDir = normalize(WorldRayDirection());    
    float3 rayOrigin = WorldRayOrigin();
    float3 blackHolePos = float3(0, 0, 0); 
     
    float b = CalculateB(rayDir, rayOrigin, blackHolePos);        
    float w0 = 0.0f;
    float w1 = 0.0f; // Updated in FindRoot
        
    float3 rayCol;   
    if (FindRoot(M, b, w1))
    {    
        // A non negative root w1 was found
        float bendAngle = 2.0f * IntegrateBendAngle(w0, w1, M, b, integrationIntervalCount) - PI;
        float3 bentRay = BendRay(rayDir, rayOrigin, blackHolePos, bendAngle);
        rayCol = skybox.SampleLevel(skyboxSampler, DirectionToSpherical(bentRay), 0).rgb;
        //rayCol = lerp(rayCol, float3(bendAngle, -bendAngle, 0.0f), 0.5f);
    }
    else
    {
        // No positive root found in the specified range - return black
        rayCol = float3(0.0f, 0.0f, 0.0f);
    }    
    
    hit.colorAndDistance = float4(rayCol, -1.0f);
    hit.normalAndIsHit = float4(0.0f, 0.0f, 0.0f, 0.0f);
    hit.rayEnergy = float4(0.0f, 0.0f, 0.0f, 0.0f);
}