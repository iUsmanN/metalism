//
//  EdgeGlowShader.metal
//  metalism
//
//  Optimised ripple layerEffect:
//  - Early exit for pixels outside the ring band (zero work for most pixels)
//  - 5×5 Gaussian kernel with pre-baked weights (25 samples vs 81)
//  - sigma and weights are compile-time constants
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// Pre-baked 5×5 Gaussian weights (sigma ≈ 1.0, normalised)
constant float kWeights[5] = { 0.0625, 0.25, 0.375, 0.25, 0.0625 };

[[ stitchable ]]
half4 edgeGlow(float2 position,
               SwiftUI::Layer layer,
               float2 touch,
               float  ringRadius,
               float  ringWidth,
               float  strength)
{
    float dist      = length(position - touch);
    float distToRing = abs(dist - ringRadius);

    // Early exit: pixel is outside the ring band — no work needed
    if (distToRing >= ringWidth || strength < 0.001) {
        return layer.sample(position);
    }

    // Falloff within the ring band
    float t = 1.0 - smoothstep(0.0, ringWidth, distToRing);
    t = t * t;
    float magnitude = t * strength;

    // Radial direction away from touch
    float2 dir = (dist > 0.5) ? ((position - touch) / dist) : float2(0.0);

    // Chromatic aberration offsets
    float aberration = magnitude * 5.0;
    float2 rPos = position + dir * aberration;
    float2 gPos = position;
    float2 bPos = position - dir * aberration;

    // 5×5 separable Gaussian blur — step size scales with blur magnitude
    float blurStep = magnitude * 1.5;   // spread in pixels per tap

    float3 blurred  = float3(0.0);
    float  weightSum = 0.0;

    for (int i = 0; i < 5; i++) {
        float ox = (float(i) - 2.0) * blurStep;
        for (int j = 0; j < 5; j++) {
            float oy = (float(j) - 2.0) * blurStep;
            float2 offset = float2(ox, oy);
            float  w      = kWeights[i] * kWeights[j];

            blurred.r  += float(layer.sample(rPos + offset).r) * w;
            blurred.g  += float(layer.sample(gPos + offset).g) * w;
            blurred.b  += float(layer.sample(bPos + offset).b) * w;
            weightSum  += w;
        }
    }

    half4 base = layer.sample(position);
    half3 result = half3(blurred / max(weightSum, 0.0001));
    return half4(result, base.a);
}
