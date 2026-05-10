//
//  BlobEdgeTanShader.metal
//  metalism
//
//  layerEffect: Refraction + warp in the outer 20% ring of a circle.
//  The distortion intensity follows a tan-based U-curve over that ring:
//  maximum at 80% radius, minimum at ~90% (mid-ring), maximum again at 100%.
//  Outside the circle pixels are untouched. Inside 80% radius no effect.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]]
half4 blobEdgeTan(float2 position,
                  SwiftUI::Layer layer,
                  float2 centre,       // circle centre in points
                  float  radius,       // circle radius in points
                  float  ringWidth)    // width of the effect ring in points (= 0.2 * radius)
{
    float2 delta = position - centre;
    float  dist  = length(delta);

    // Outside the circle — untouched
    if (dist > radius) {
        return layer.sample(position);
    }

    // Inside the inner boundary (60% of radius) — untouched
    float innerBoundary = radius - ringWidth;
    if (dist < innerBoundary) {
        return layer.sample(position);
    }

    // u ∈ [0, 1]: 0 = inner edge (80%), 1 = outer edge (100%)
    float u = (dist - innerBoundary) / ringWidth;

    // Map u → angle in (−π/2, π/2), staying away from poles for smoothness.
    // A larger epsilon means shallower poles → smoother, more gradual U-shape.
    float halfPi  = 1.5707963;
    float epsilon = 0.15;          // wide margin → gentle tan curve
    float angle   = u * (2.0 * halfPi - 2.0 * epsilon) - (halfPi - epsilon);

    // abs(tan) gives U-shape: high at both ends (u=0, u=1), zero at centre (u=0.5).
    float tanMax  = tan(halfPi - epsilon);
    float tanVal  = abs(tan(angle));
    float tanNorm = saturate(tanVal / tanMax);

    // Lift the valley with a sqrt so the mid-ring still shows visible effect,
    // making the U feel like a smooth wave rather than a hard notch.
    tanNorm = pow(tanNorm, 0.45);

    float2 radial  = dist > 0.001 ? normalize(delta) : float2(1.0, 0.0);
    float2 tangent = float2(-radial.y, radial.x);

    // ── Refraction (inward pull, peaks at both ring edges) ───────────────────
    float refrAmt     = tanNorm * 64.0;
    float2 refrOffset = -radial * refrAmt;

    // ── Warp (tangential shear, still U-shaped but with visible mid effect) ──
    float warpAmt     = tanNorm * 28.0;
    float2 warpOffset = tangent * warpAmt;

    float2 sampleBase = position + refrOffset + warpOffset;

    // ── Chromatic aberration proportional to tanNorm ─────────────────────────
    float caAmt = tanNorm * 14.0;

    // ── 8-tap radial blur ─────────────────────────────────────────────────────
    float blurSpread = tanNorm * 20.0;

    float3 sumR = float3(0), sumG = float3(0), sumB = float3(0);
    float  wTotal = 0.0;

    for (int i = 0; i < 8; i++) {
        float  a   = (float(i) / 8.0) * 6.28318;
        float2 off = float2(cos(a), sin(a)) * blurSpread;
        sumR += float3(layer.sample(sampleBase + off + radial * caAmt).r);
        sumG += float3(layer.sample(sampleBase + off).g);
        sumB += float3(layer.sample(sampleBase + off - radial * caAmt).b);
        wTotal += 1.0;
    }
    // Centre tap (weight 3×)
    sumR += float3(layer.sample(sampleBase + radial * caAmt).r) * 3.0;
    sumG += float3(layer.sample(sampleBase).g)                  * 3.0;
    sumB += float3(layer.sample(sampleBase - radial * caAmt).b) * 3.0;
    wTotal += 3.0;

    half r = half(sumR.r / wTotal);
    half g = half(sumG.g / wTotal);
    half b = half(sumB.b / wTotal);

    half4 original = layer.sample(position);
    return half4(
        mix(original.r, r, half(tanNorm)),
        mix(original.g, g, half(tanNorm)),
        mix(original.b, b, half(tanNorm)),
        1.0h
    );
}
