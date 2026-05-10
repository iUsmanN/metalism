//
//  LiquidBlockShader.metal
//  metalism
//
//  layerEffect: Rounded-rectangle with a Gaussian blur across the entire
//  interior, plus refraction, warp and CA at the edges.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

static float rrectSDF(float2 p, float2 b, float r) {
    float2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

[[ stitchable ]]
half4 liquidBlock(float2 position,
                  SwiftUI::Layer layer,
                  float2 centre,
                  float2 halfExtents,
                  float  cornerRadius,
                  float  ringWidth)
{
    float2 delta = position - centre;
    float  sdf   = rrectSDF(delta, halfExtents, cornerRadius);

    // Outside the rect — return original pixel untouched
    if (sdf > 0.0) {
        return layer.sample(position);
    }

    // Normalised depth: 0 = centre, 1 = edge
    float maxDist = min(halfExtents.x, halfExtents.y);

    // Outward normal via SDF gradient
    float eps = 1.0;
    float2 grad = normalize(float2(
        rrectSDF(delta + float2(eps, 0.0), halfExtents, cornerRadius) -
        rrectSDF(delta - float2(eps, 0.0), halfExtents, cornerRadius),
        rrectSDF(delta + float2(0.0, eps), halfExtents, cornerRadius) -
        rrectSDF(delta - float2(0.0, eps), halfExtents, cornerRadius)
    ));
    float2 radial  = grad;
    float2 tangent = float2(-radial.y, radial.x);

    // Edge ring factor (0 inside, 1 at edge)
    float distFromEdge = -sdf;
    float t = 1.0 - smoothstep(0.0, ringWidth, distFromEdge);

    float2 sampleBase = position;

    // ── Gaussian blur — separable 5×5 kernel, sigma ≈ 8 px ───────────────────
    const float sigma   = 8.0;
    const float step    = sigma * 0.8;
    const float w0      = 0.2270;
    const float w1      = 0.1945;
    const float w2      = 0.1216;
    const int   HALF    = 2;

    float caAmt = t * 3.0;
    float3 sumR = float3(0), sumG = float3(0), sumB = float3(0);
    float  wTotal = 0.0;

    for (int ix = -HALF; ix <= HALF; ix++) {
        float wx = (ix == 0) ? w0 : (abs(ix) == 1 ? w1 : w2);
        for (int iy = -HALF; iy <= HALF; iy++) {
            float wy  = (iy == 0) ? w0 : (abs(iy) == 1 ? w1 : w2);
            float w   = wx * wy;
            float2 off = float2(float(ix), float(iy)) * step;
            sumR += float3(layer.sample(sampleBase + off + radial * caAmt).r) * w;
            sumG += float3(layer.sample(sampleBase + off).g)                  * w;
            sumB += float3(layer.sample(sampleBase + off - radial * caAmt).b) * w;
            wTotal += w;
        }
    }

    half r = half(sumR.r / wTotal);
    half g = half(sumG.g / wTotal);
    half b = half(sumB.b / wTotal);

    return half4(r, g, b, 1.0h);
}
