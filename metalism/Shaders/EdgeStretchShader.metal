//
//  EdgeStretchShader.metal
//  metalism
//
//  layerEffect shader applied to the whole list view.
//  Pixels near the vertical centre are sampled normally.
//  Pixels toward the top/bottom edges have their horizontal UV
//  compressed toward the centre, making the content appear stretched/spread out.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

/// layerEffect signature:
///   half4 edgeStretch(float2 position, SwiftUI::Layer layer, float2 size, float strength)
///
/// position – destination pixel in view-local coordinates
/// layer    – rasterised source content
/// size     – full size of the view (.float2 uniform)
/// strength – how much to stretch at the extreme edges (0 = none, try 0.5–1.5)
[[ stitchable ]]
half4 edgeStretch(float2 position,
                  SwiftUI::Layer layer,
                  float2 size,
                  float strength)
{
    // Normalised vertical distance from centre: 0 at centre, 1 at top/bottom
    float normY = abs(position.y - size.y * 0.5) / (size.y * 0.5);

    // Smooth the falloff so it eases in near the edges (smoothstep)
    float t = smoothstep(0.0, 1.0, normY);

    // Horizontal stretch: compress the sample X toward centre
    // At t=0 (centre): no shift. At t=1 (edge): pixels pulled inward by (strength * size.x * 0.5)
    float centreX   = size.x * 0.5;
    float offsetX   = (position.x - centreX) * (1.0 - t * strength);
    float sampleX   = centreX + offsetX;

    return layer.sample(float2(sampleX, position.y));
}
