//
//  BlobSquareEdgeShader.metal
//  metalism
//
//  layerEffect: Same effects as BlobEdgeShader but shaped as a square.
//  Uses Chebyshev (L∞) distance so the "circle" becomes a square.
//  • Blur: max at edges, zero at 80% of half-size inward
//  • Refraction + warp + CA in the outer ring
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]]
half4 blobSquareEdge(float2 position,
                     SwiftUI::Layer layer,
                     float2 centre,       // square centre in points
                     float  halfSize,     // half side-length in points
                     float  ringWidth)    // width of effect ring in points
{
    float2 delta = position - centre;

    // Chebyshev distance = max(|dx|, |dy|) → square boundary
    float cheby = max(abs(delta.x), abs(delta.y));

    // Outside the square — untouched
    if (cheby > halfSize) {
        return layer.sample(position);
    }

    // Normalised depth: 0 = centre, 1 = edge
    float depthN = cheby / halfSize;

    // Outward normal in Chebyshev space: push along the dominant axis
    float2 radial;
    if (abs(delta.x) >= abs(delta.y)) {
        radial = float2(sign(delta.x), 0.0);
    } else {
        radial = float2(0.0, sign(delta.y));
    }
    float2 tangent = float2(-radial.y, radial.x);

    // t: effect ring driven by distance from the square edge
    float distFromEdge = halfSize - cheby;
    float t = 1.0 - smoothstep(0.0, ringWidth, distFromEdge);

    // ── Refraction ────────────────────────────────────────────────────────────
    float refrAmt     = t * t * 48.0;
    float2 refrOffset = -radial * refrAmt;

    // ── Warp ──────────────────────────────────────────────────────────────────
    float warpAmt     = t * (1.0 - t) * 32.0;
    float2 warpOffset = tangent * warpAmt;

    float2 sampleBase = position + refrOffset + warpOffset;

    // ── Blur: max at edge, zero at 80% depth ──────────────────────────────────
    float blurT      = smoothstep(0.80, 1.0, depthN);
    float blurSpread = blurT * 12.0;

    float caAmt = t * 10.0;

    float3 sumR = float3(0), sumG = float3(0), sumB = float3(0);
    float  wTotal = 0.0;

    for (int i = 0; i < 8; i++) {
        float  angle = (float(i) / 8.0) * 6.28318;
        float2 off   = float2(cos(angle), sin(angle)) * blurSpread;
        sumR += float3(layer.sample(sampleBase + off + radial * caAmt).r);
        sumG += float3(layer.sample(sampleBase + off).g);
        sumB += float3(layer.sample(sampleBase + off - radial * caAmt).b);
        wTotal += 1.0;
    }
    // Centre tap at 3× weight
    sumR += float3(layer.sample(sampleBase + radial * caAmt).r) * 3.0;
    sumG += float3(layer.sample(sampleBase).g)                  * 3.0;
    sumB += float3(layer.sample(sampleBase - radial * caAmt).b) * 3.0;
    wTotal += 3.0;

    half r = half(sumR.r / wTotal);
    half g = half(sumG.g / wTotal);
    half b = half(sumB.b / wTotal);

    float blend   = max(t, blurT);
    half4 original = layer.sample(position);
    return half4(
        mix(original.r, r, half(blend)),
        mix(original.g, g, half(blend)),
        mix(original.b, b, half(blend)),
        1.0h
    );
}
