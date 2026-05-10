//
//  SwitchGlowShader.metal
//  metalism
//
//  A ring that expands from the card centre to its bounds.
//  The shape morphs from a circle at the start to a square at the end,
//  controlled by the `squareness` parameter (0 = circle, 1 = square).
//  Blur + chromatic aberration ride the wavefront and fade with strength.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

constant float sgWeights[5] = { 0.0625, 0.25, 0.375, 0.25, 0.0625 };

[[ stitchable ]]
half4 switchGlow(float2 position,
                 SwiftUI::Layer layer,
                 float2 centre,
                 float  ringRadius,   // current radius of the wavefront
                 float  ringWidth,    // half-width of the effect band
                 float  squareness,   // 0 = circle, 1 = square (Chebyshev dist)
                 float  strength)
{
    if (strength < 0.001) {
        return layer.sample(position);
    }

    float2 delta = position - centre;

    // Lerp between Euclidean and Chebyshev (L∞) distance
    float euclidean  = length(delta);
    float chebyshev  = max(abs(delta.x), abs(delta.y));
    float dist       = mix(euclidean, chebyshev, squareness);

    float distToRing = abs(dist - ringRadius);

    // Early exit outside the ring band
    if (distToRing >= ringWidth) {
        return layer.sample(position);
    }

    // Smooth falloff within the ring band — peak at wavefront
    float t = 1.0 - smoothstep(0.0, ringWidth, distToRing);
    t = t * t;
    float magnitude = t * strength;

    // Radial direction for chromatic aberration
    // Use the normalised blended direction so it stays square-aligned near squareness=1
    float2 dir = float2(0.0);
    if (euclidean > 0.5) {
        float2 euclidDir   = delta / euclidean;
        float2 chebyDir    = delta / max(chebyshev, 0.001);
        dir = normalize(mix(euclidDir, chebyDir, squareness));
    }

    float aberration = magnitude * 8.0;
    float2 rPos = position + dir * aberration;
    float2 gPos = position;
    float2 bPos = position - dir * aberration;

    float blurStep = magnitude * 2.5;

    float3 blurred  = float3(0.0);
    float  weightSum = 0.0;

    for (int i = 0; i < 5; i++) {
        float ox = (float(i) - 2.0) * blurStep;
        for (int j = 0; j < 5; j++) {
            float oy = (float(j) - 2.0) * blurStep;
            float2 offset = float2(ox, oy);
            float  w      = sgWeights[i] * sgWeights[j];

            blurred.r  += float(layer.sample(rPos + offset).r) * w;
            blurred.g  += float(layer.sample(gPos + offset).g) * w;
            blurred.b  += float(layer.sample(bPos + offset).b) * w;
            weightSum  += w;
        }
    }

    half4 base   = layer.sample(position);
    half3 result = half3(blurred / max(weightSum, 0.0001));
    return half4(result, base.a);
}
