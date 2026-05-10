//
//  BlobSquareEdgeTanShader.metal
//  metalism
//
//  layerEffect: Square-shaped version of BlobEdgeTanShader.
//  Uses Chebyshev (L∞) distance so the boundary is a square.
//  The 60–100% ring has: tan U-curve distortion, Gaussian blur,
//  specular highlights that rotate with scroll, and 20% darkening.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]]
half4 blobSquareEdgeTan(float2 position,
                        SwiftUI::Layer layer,
                        float2 centre,        // square centre in points
                        float  halfSize,      // half side-length in points
                        float  ringWidth,     // width of the effect ring in points (40% of halfSize)
                        float  scrollOffset,  // scroll position — rotates specular
                        float  blurRadius)    // Gaussian blur radius in points
{
    float2 delta = position - centre;

    // Chebyshev distance → square boundary
    float cheby = max(abs(delta.x), abs(delta.y));

    // Outside the square — untouched
    if (cheby > halfSize) {
        return layer.sample(position);
    }

    // No inner boundary — the full 0–100% interior is the ring
    float innerBoundary = 0.0;

    // u ∈ [0, 1]: 0 = centre (0%), 1 = outer edge (100%)
    float u = (cheby - innerBoundary) / ringWidth;

    // Tan U-curve: high at u=0 and u=1, low at u=0.5
    float halfPi  = 1.5707963;
    float epsilon = 0.1;
    float angle   = u * (2.0 * halfPi - 2.0 * epsilon) - (halfPi - epsilon);
    float tanMax  = tan(halfPi - epsilon);
    float tanVal  = abs(tan(angle));
    float tanNorm = saturate(tanVal / tanMax);
    tanNorm = pow(tanNorm, 0.45);   // lift the valley

    // Outward normal in Chebyshev space (axis-aligned face normal)
    float2 radial;
    if (abs(delta.x) >= abs(delta.y)) {
        radial = float2(sign(delta.x), 0.0);
    } else {
        radial = float2(0.0, sign(delta.y));
    }
    float2 tangent = float2(-radial.y, radial.x);

    // ── Refraction ────────────────────────────────────────────────────────────
    float2 refrOffset = -radial * tanNorm * 64.0;

    // ── Warp ──────────────────────────────────────────────────────────────────
    float2 warpOffset = tangent * tanNorm * 28.0;

    float2 sampleBase = position + refrOffset + warpOffset;

    // ── Chromatic aberration ──────────────────────────────────────────────────
    float caAmt = tanNorm * 14.0;

    // ── Gaussian blur — uniform across the full ring ──────────────────────────
    float sigma  = blurRadius * 0.5;
    float step   = sigma * 0.6;

    float3 sumR = float3(0), sumG = float3(0), sumB = float3(0);
    float  wTotal = 0.0;

    float w0 = 1.0;
    sumR   += float3(layer.sample(sampleBase + radial * caAmt).r) * w0;
    sumG   += float3(layer.sample(sampleBase).g)                  * w0;
    sumB   += float3(layer.sample(sampleBase - radial * caAmt).b) * w0;
    wTotal += w0;

    for (int k = 1; k <= 6; k++) {
        float t  = float(k);
        float wk = exp(-(t * t) / (2.0 * sigma * sigma / (step * step)));
        float o  = t * step;

        float2 px = float2(o, 0.0);
        float2 py = float2(0.0, o);

        sumR   += float3(layer.sample(sampleBase + px + radial * caAmt).r
                       + layer.sample(sampleBase - px + radial * caAmt).r) * wk;
        sumG   += float3(layer.sample(sampleBase + px).g
                       + layer.sample(sampleBase - px).g)                  * wk;
        sumB   += float3(layer.sample(sampleBase + px - radial * caAmt).b
                       + layer.sample(sampleBase - px - radial * caAmt).b) * wk;

        sumR   += float3(layer.sample(sampleBase + py + radial * caAmt).r
                       + layer.sample(sampleBase - py + radial * caAmt).r) * wk;
        sumG   += float3(layer.sample(sampleBase + py).g
                       + layer.sample(sampleBase - py).g)                  * wk;
        sumB   += float3(layer.sample(sampleBase + py - radial * caAmt).b
                       + layer.sample(sampleBase - py - radial * caAmt).b) * wk;

        wTotal += wk * 4.0;
    }

    float3 distorted = float3(sumR.r / wTotal, sumG.g / wTotal, sumB.b / wTotal);

    // ── Specular highlight — rotates with scroll ──────────────────────────────
    float scrollAngle = scrollOffset * 0.008;
    float cosS = cos(scrollAngle), sinS = sin(scrollAngle);

    float2 baseLight1 = normalize(float2( 0.6, -0.8));
    float2 baseLight2 = normalize(float2(-0.7,  0.5));
    float2 light1 = float2(cosS * baseLight1.x - sinS * baseLight1.y,
                           sinS * baseLight1.x + cosS * baseLight1.y);
    float2 light2 = float2(cosS * baseLight2.x - sinS * baseLight2.y,
                           sinS * baseLight2.x + cosS * baseLight2.y);

    float spec1 = pow(saturate(dot(radial, light1)), 22.0);
    float spec2 = pow(saturate(dot(radial, light2)), 10.0);

    float3 specColor = spec1 * float3(1.0, 0.96, 0.88) * 0.28
                     + spec2 * float3(0.78, 0.88, 1.0)  * 0.14;
    specColor *= tanNorm;

    // ── 20% darkness + specular ───────────────────────────────────────────────
    float3 finalColor = saturate(distorted * 0.80 + specColor);

    // Smooth 4pt fade at both boundaries
    float innerFade = smoothstep(innerBoundary, innerBoundary + 4.0, cheby);
    float outerFade = smoothstep(halfSize, halfSize - 4.0, cheby);
    float ringMask  = innerFade * outerFade;

    half4 original = layer.sample(position);
    float3 blended = mix(float3(original.rgb), finalColor, ringMask);

    return half4(half3(blended), 1.0h);
}
