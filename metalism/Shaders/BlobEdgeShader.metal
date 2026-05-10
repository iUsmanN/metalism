//
//  BlobEdgeShader.metal
//  metalism
//
//  layerEffect: Chromatic aberration + refraction + warp in a ring inside a circle.
//  Pixels outside the circle are untouched. Inside the ring near the edge:
//  • Refraction: sample pulled inward (convex-lens bend)
//  • Warp: tangential shear adds a swirl/distortion at the rim
//  • CA: R/G/B split radially
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]]
half4 blobEdge(float2 position,
               SwiftUI::Layer layer,
               float2 centre,       // circle centre in points
               float  radius,       // circle radius in points
               float  ringWidth)    // width of the effect ring in points
{
    float2 delta = position - centre;
    float  dist  = length(delta);

    // Pixels outside the circle are untouched
    if (dist > radius) {
        return layer.sample(position);
    }

    // normalised depth: 0 = centre, 1 = edge
    float depthN = dist / radius;

    // t for refraction/warp/CA ring — same as before (outer 20%)
    float distFromEdge = radius - dist;
    float t = 1.0 - smoothstep(0.0, ringWidth, distFromEdge);

    float2 radial  = dist > 0.001 ? normalize(delta) : float2(1.0, 0.0);
    float2 tangent = float2(-radial.y, radial.x);

    // ── Refraction ────────────────────────────────────────────────────────────
    float refrAmt     = t * t * 48.0;
    float2 refrOffset = -radial * refrAmt;

    // ── Warp ──────────────────────────────────────────────────────────────────
    float warpAmt     = t * (1.0 - t) * 32.0;
    float2 warpOffset = tangent * warpAmt;

    float2 sampleBase = position + refrOffset + warpOffset;

    // ── Blur: max at edge (depthN=1), zero at 80% radius (depthN=0.8) ─────────
    float blurT      = smoothstep(0.80, 1.0, depthN);   // 0→1 over outer 20%
    float maxBlur    = 16.0;
    float blurSpread = blurT * maxBlur;

    // 8-tap radial blur around the (refracted+warped) base position
    float3 sumR = float3(0), sumG = float3(0), sumB = float3(0);
    float  wTotal = 0.0;
    float  caAmt  = t * 10.0;

    for (int i = 0; i < 8; i++) {
        float  angle = (float(i) / 8.0) * 6.28318;
        float2 off   = float2(cos(angle), sin(angle)) * blurSpread;
        sumR += float3(layer.sample(sampleBase + off + radial * caAmt).r);
        sumG += float3(layer.sample(sampleBase + off).g);
        sumB += float3(layer.sample(sampleBase + off - radial * caAmt).b);
        wTotal += 1.0;
    }
    // Centre tap (weight 3×) preserves some sharpness at lower blur levels
    sumR += float3(layer.sample(sampleBase + radial * caAmt).r) * 3.0;
    sumG += float3(layer.sample(sampleBase).g)                  * 3.0;
    sumB += float3(layer.sample(sampleBase - radial * caAmt).b) * 3.0;
    wTotal += 3.0;

    half r = half(sumR.r / wTotal);
    half g = half(sumG.g / wTotal);
    half b = half(sumB.b / wTotal);

    // Blend with unaffected original using max of t and blurT
    float blend = max(t, blurT);
    half4 original = layer.sample(position);
    return half4(
        mix(original.r, r, half(blend)),
        mix(original.g, g, half(blend)),
        mix(original.b, b, half(blend)),
        1.0h
    );
}
