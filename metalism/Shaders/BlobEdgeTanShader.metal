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
                  float2 centre,        // circle centre in points
                  float  radius,        // circle radius in points
                  float  ringWidth,     // width of the effect ring in points
                  float  scrollOffset)  // scroll position in points — rotates specular
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
    float epsilon = 0.1;          // wide margin → gentle tan curve
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

    // ── Gouging blur: radial streak + tangential smear ────────────────────────
    // Radial streak: samples dragged inward toward centre (like a gouge/scrape).
    // Tangential smear: samples swept along the ring arc.
    // Both lengths follow the tan U-curve so the blur peaks at 60% and 100%.
    float radialStreak    = tanNorm * 36.0;   // inward drag length
    float tangentialSmear = tanNorm * 24.0;   // arc smear length
    int   taps            = 12;

    float3 sumR = float3(0), sumG = float3(0), sumB = float3(0);
    float  wTotal = 0.0;

    for (int i = 0; i < taps; i++) {
        // Exponentially spaced weights — heavier near centre tap for softer falloff
        float s = float(i) / float(taps - 1);          // 0 → 1
        float w = exp(-s * 2.5);                        // Gaussian-ish weight

        // Radial gouge: streak inward (negative radial = toward centre)
        float2 rOff = -radial * s * radialStreak;
        sumR   += float3(layer.sample(sampleBase + rOff + radial * caAmt).r) * w;
        sumG   += float3(layer.sample(sampleBase + rOff).g)                  * w;
        sumB   += float3(layer.sample(sampleBase + rOff - radial * caAmt).b) * w;
        wTotal += w;

        // Tangential smear: sweep both directions along arc
        float2 tOff = tangent * (s - 0.5) * tangentialSmear;
        sumR   += float3(layer.sample(sampleBase + tOff + radial * caAmt).r) * w * 0.5;
        sumG   += float3(layer.sample(sampleBase + tOff).g)                  * w * 0.5;
        sumB   += float3(layer.sample(sampleBase + tOff - radial * caAmt).b) * w * 0.5;
        wTotal += w * 0.5;
    }

    float3 distorted = float3(sumR.r / wTotal, sumG.g / wTotal, sumB.b / wTotal);

    // ── Specular highlight ────────────────────────────────────────────────────
    // The light directions slowly rotate as content scrolls, so the highlight
    // appears to slide around the ring with the movement behind it.
    // scrollOffset is in points; divide by rowHeight-equivalent to get turns.
    float scrollAngle = scrollOffset * 0.008;   // slow rotation per point scrolled
    float cosS = cos(scrollAngle), sinS = sin(scrollAngle);

    // Rotate two fixed light directions by the scroll angle
    float2 baseLight1 = normalize(float2( 0.6, -0.8));
    float2 baseLight2 = normalize(float2(-0.7,  0.5));
    float2 light1 = float2(cosS * baseLight1.x - sinS * baseLight1.y,
                           sinS * baseLight1.x + cosS * baseLight1.y);
    float2 light2 = float2(cosS * baseLight2.x - sinS * baseLight2.y,
                           sinS * baseLight2.x + cosS * baseLight2.y);

    float spec1 = pow(saturate(dot(radial, light1)), 22.0);   // tight key
    float spec2 = pow(saturate(dot(radial, light2)), 10.0);   // soft fill

    // Subtle warm/cool tint, low intensity
    float3 specColor = spec1 * float3(1.0, 0.96, 0.88) * 0.28
                     + spec2 * float3(0.78, 0.88, 1.0)  * 0.14;

    // Scale by tanNorm so highlight follows the U-curve within the ring
    specColor *= tanNorm;

    // ── Uniform 20% darkness across the full 60–100% ring ────────────────────
    // Applied flat — no sin modulation — so every pixel in the ring is equally dimmed.
    float3 dimmed     = distorted * 1.20;
    float3 finalColor = saturate(dimmed + specColor);

    half4 original = layer.sample(position);
    // Blend the darkened+specular result against the original using tanNorm,
    // so the effect still fades in smoothly at the ring boundaries.
    float3 blended = mix(float3(original.rgb), finalColor, tanNorm);

    return half4(half3(blended), 1.0h);
}
