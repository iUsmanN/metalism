//
//  DonutGlowShader.metal
//  metalism
//
//  Doughnut-style layerEffect:
//  - Inside innerRadius: no effect (clear zone)
//  - Between innerRadius and outerRadius: blur + chromatic aberration,
//    ramping up from 0 at the inner edge to peak at mid-ring, back to 0 at outer edge
//  - Outside outerRadius: no effect
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// Pre-baked 5×5 Gaussian weights (sigma ≈ 1.0, normalised)
constant float dkWeights[5] = { 0.0625, 0.25, 0.375, 0.25, 0.0625 };

[[ stitchable ]]
half4 donutGlow(float2 position,
                SwiftUI::Layer layer,
                float2 touch,
                float  innerRadius,
                float  outerRadius,
                float  strength)
{
    float dist = length(position - touch);

    // Clear zone inside inner radius, and outside outer radius
    if (dist <= innerRadius || dist >= outerRadius || strength < 0.001) {
        return layer.sample(position);
    }

    // Normalise position within the ring [0, 1]
    float ringT = (dist - innerRadius) / (outerRadius - innerRadius);

    // Smooth ramp: peaks at mid-ring, zero at both edges
    float t = smoothstep(0.0, 0.5, ringT) * (1.0 - smoothstep(0.5, 1.0, ringT));
    t = t * t;
    float magnitude = t * strength;

    // Radial direction away from touch centre
    float2 dir = (dist > 0.5) ? ((position - touch) / dist) : float2(0.0);

    // Chromatic aberration: R pushed outward, B inward, G stays
    float aberration = magnitude * 6.0;
    float2 rPos = position + dir * aberration;
    float2 gPos = position;
    float2 bPos = position - dir * aberration;

    // 5×5 Gaussian blur with step scaling with magnitude
    float blurStep = magnitude * 2.0;

    float3 blurred  = float3(0.0);
    float  weightSum = 0.0;

    for (int i = 0; i < 5; i++) {
        float ox = (float(i) - 2.0) * blurStep;
        for (int j = 0; j < 5; j++) {
            float oy = (float(j) - 2.0) * blurStep;
            float2 offset = float2(ox, oy);
            float  w      = dkWeights[i] * dkWeights[j];

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
