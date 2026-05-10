//
//  RedBottomShader.metal
//  metalism
//
//  layerEffect that tints the bottom 10% red AND stretches pixels vertically.
//  The stretch amount scales with the red intensity — deeper red = more stretch.
//  Works on a pure SwiftUI ScrollView (no UIKit List).
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]]
half4 redBottom(float2 position,
                SwiftUI::Layer layer,
                float2 size)
{
    float normY = position.y / size.y;

    // Red intensity: 0 above 90%, ramps to 1 at 100%
    float t = smoothstep(0.90, 1.0, normY);

    // Stretch: pull sample upward proportional to t
    // At the very bottom edge, sample from further up (max ~8% of height)
    float stretchOffset = t * t * size.y * 0.08;
    float2 samplePos = float2(position.x, position.y - stretchOffset);
    samplePos = clamp(samplePos, float2(0.0), size - 1.0);

    half4 color = layer.sample(samplePos);

    // Tint red proportional to t
    color.r = clamp(color.r + half(t * 0.85), half(0.0), half(1.0));
    color.g = color.g * half(1.0 - t * 0.9);
    color.b = color.b * half(1.0 - t * 0.9);

    return color;
}
