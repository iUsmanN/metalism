//
//  WarpTouchShader.metal
//  metalism
//
//  Single-pass layerEffect. Accumulates stretch + brightness from all
//  active trail points. Each point contributes based on its radial
//  falloff and pre-faded strength.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]]
half4 warpTouch(float2 position,
                SwiftUI::Layer layer,
                float2 size,
                device const float *points    [[ buffer(0) ]],
                int    pointsCount,
                device const float *dirs      [[ buffer(1) ]],
                int    dirsCount,
                device const float *strengths [[ buffer(2) ]],
                int    strengthsCount,
                float  radius)
{
    int count = strengthsCount;

    float2 totalDisplace = float2(0.0);

    for (int i = 0; i < count; i++) {
        float2 touch = float2(points[i * 2], points[i * 2 + 1]);
        float2 delta = position - touch;
        float  dist  = length(delta);

        float t = 1.0 - smoothstep(0.0, radius, dist);
        t = t * t;

        float2 dir      = float2(dirs[i * 2], dirs[i * 2 + 1]);
        float  strength = strengths[i];
        float  effect   = t * strength;

        totalDisplace += dir * effect;
    }

    // Clamp total displacement
    float dispLen = length(totalDisplace);
    if (dispLen > 120.0) {
        totalDisplace = totalDisplace / dispLen * 120.0;
    }

    // Smooth the displacement with a gentle ease — avoids sharp pixel jumps
    float2 smoothed  = totalDisplace * 0.85;
    float2 samplePos = clamp(position - smoothed, float2(0.0), size - 1.0);

    return layer.sample(samplePos);
}
