//
//  BlobEdgeTan2Shader.metal
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
half4 blobEdgeTan2(float2 position,
                   SwiftUI::Layer layer,
                   float2 centre,        // circle centre in points
                   float  radius,        // circle radius in points
                   float  ringWidth,     // width of the effect ring in points
                   float  scrollOffset,  // scroll position in points — rotates specular
                   float  blurRadius)    // Gaussian blur radius in points (e.g. 50.0)
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

    // ── Gaussian blur — uniform across the full 60–100% ring ──────────────────
    // Approximated as a cross-shaped 2D gather: 12 taps along X + 12 along Y,
    // spaced at sigma * 0.6 intervals. Weights are exp(-k²/2σ²) normalised.
    float sigma  = blurRadius * 0.5;   // sigma ≈ half the desired radius
    float step   = sigma * 0.6;        // spacing between taps

    float3 sumR = float3(0), sumG = float3(0), sumB = float3(0);
    float  wTotal = 0.0;

    // Centre tap
    float w0 = 1.0;
    sumR   += float3(layer.sample(sampleBase + radial * caAmt).r) * w0;
    sumG   += float3(layer.sample(sampleBase).g)                  * w0;
    sumB   += float3(layer.sample(sampleBase - radial * caAmt).b) * w0;
    wTotal += w0;

    // 6 symmetric pairs along X and Y (k = 1..6)
    for (int k = 1; k <= 6; k++) {
        float t  = float(k);
        float wk = exp(-(t * t) / (2.0 * sigma * sigma / (step * step)));
        float o  = t * step;

        float2 px = float2(o, 0.0);
        float2 py = float2(0.0, o);

        // +X / -X
        sumR   += float3(layer.sample(sampleBase + px + radial * caAmt).r
                       + layer.sample(sampleBase - px + radial * caAmt).r) * wk;
        sumG   += float3(layer.sample(sampleBase + px).g
                       + layer.sample(sampleBase - px).g)                  * wk;
        sumB   += float3(layer.sample(sampleBase + px - radial * caAmt).b
                       + layer.sample(sampleBase - px - radial * caAmt).b) * wk;

        // +Y / -Y
        sumR   += float3(layer.sample(sampleBase + py + radial * caAmt).r
                       + layer.sample(sampleBase - py + radial * caAmt).r) * wk;
        sumG   += float3(layer.sample(sampleBase + py).g
                       + layer.sample(sampleBase - py).g)                  * wk;
        sumB   += float3(layer.sample(sampleBase + py - radial * caAmt).b
                       + layer.sample(sampleBase - py - radial * caAmt).b) * wk;

        wTotal += wk * 4.0;   // 4 taps per k (±X, ±Y)
    }

    float3 distorted = float3(sumR.r / wTotal, sumG.g / wTotal, sumB.b / wTotal);

    // ── Specular highlight ────────────────────────────────────────────────────
    // The light directions slowly rotate as content scrolls, so the highlight
    // appears to slide around the ring with the movement behind it.
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
    float3 dimmed     = distorted * 0.80;
    float3 finalColor = saturate(dimmed + specColor);

    // Smooth edge fade over 4pt at inner and outer boundaries
    float innerFade = smoothstep(innerBoundary, innerBoundary + 4.0, dist);
    float outerFade = smoothstep(radius, radius - 4.0, dist);
    float ringMask  = innerFade * outerFade;

    half4 original = layer.sample(position);
    float3 blended = mix(float3(original.rgb), finalColor, ringMask);

    return half4(half3(blended), 1.0h);
}
